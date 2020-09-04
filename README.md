# AGMPowerLib
A Library of PowerShell Scripts to interact with AGM

## Prerequisite

This module requires AGMPowerCLI to already be installed.
Please visit this repo first:  https://github.com/Actifio/AGMPowerCLI-Beta


### Install or Upgrade AGMPowerLib

Install from PowerShell Gallery:

```
Install-Module -Name AGMPowerLib
```

If the install worked, you can now move on.

#### Upgrades using PowerShell Gallery

Note if you run 'Install-Module' to update an installed module, it will complain.  You need to run:
```
Update-Module -name AGMPowerLib
```
It will install the latest version and leave the older version in place.  To see the version in use versus all versions downloaded use these two commands:
```
Get-InstalledModule AGMPowerLib
Get-InstalledModule AGMPowerLib -AllVersions
```
To uninstall all older versions run this command:
```
$Latest = Get-InstalledModule AGMPowerLib; Get-InstalledModule AGMPowerLib -AllVersions | ? {$_.Version -ne $Latest.Version} | Uninstall-Module
```

#### Manual install

Serious corporate servers will not allow downloads from PowerShell gallery or even access to GitHub from Production Servers, so for these we have the following process:

1.  From GitHub, use the Green Code download button to download the AGMPowerLib repo as a zip file
1.  Copy the Zip file to the server where you want to install it
1.  For Windows, Right select on the zip file, choose  Properties and then use the Unblock button next to the message:  "This file came from another computer and might be blocked to help protect  your computer."
1.  For Windows, now right select and use Extract All to extract the contents of the zip file to a folder.  It doesn't matter where you put the folder.  For Mac it should automatically unzip.  For Linux use the unzip command to unzip the folder.
1.  Now start PWSH and change directory to the  AGMPowerLib-main directory that should contain our module files.   
1.  There is an installer, Install-AGMPowerLib.ps1 so run that with ./Install-AGMPowerLib.ps1
If you find multiple installs, we strongly recommend you delete them all and run the installer again to have just one install.


If the install fails with:
```
PS C:\Users\av\Downloads\AGMPowerLib-main\AGMPowerLib-main> .\Install-AGMPowerLib.ps1
.\Install-AGMPowerLib.ps1: File C:\Users\av\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 cannot be loaded. 
The file C:\Users\av\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 is not digitally signed. 
You cannot run this script on the current system. For more information about running scripts and setting execution policy, see about_Execution_Policies at https://go.microsoft.com/fwlink/?LinkID=135170.
```
Then  run this command:
```
Get-ChildItem .\Install-AGMPowerLib.ps1 | Unblock-File
```
Then re-run the installer.  The installer will unblock all the files.

## Guided Wizards

The following functions have guided wizards to help you create commands.   Simply run these commands without any options to start the wizard:

Database mounts:
```
New-AGMLibContainerMount
New-AGMLibOracleMount
New-AGMLibMSSQLMount
```
New VM mounts:
```
New-AGMLibAWSVM
New-AGMLibAzureVM
New-AGMLibGCPVM
New-AGMLibSystemStateToVM
New-AGMLibVM 
New-AGMLibVMExisting 
```

# User Story - Database Mounts
Here are some user stories for Database mounts

### SQL Test and Dev Image usage

In this 'story' a user wants to mount the latest snapshot of a SQL DB to a host

The User creates a password key

```
PS /Users/anthony> Save-AGMPassword
Filename: av.key
Password: **********
Password saved to av.key.
You may now use -passwordfile with Connect-AGM to provide a saved password file.
```

The user connects to AGM:

```
PS /Users/anthony> Connect-AGM 172.24.1.117 av -passwordfile av.key -i
Login Successful!
```

The user finds the appID for the source DB

```
PS /Users/anthony> Get-AGMLibApplicationID smalldb

id      friendlytype hostname appname appliancename applianceip  appliancetype managed
--      ------------ -------- ------- ------------- -----------  ------------- -------
5552336 SQLServer    hq-sql   smalldb sa-sky        172.24.1.180 Sky              True
261762  Oracle       oracle   smalldb sa-sky        172.24.1.180 Sky              True
```

The user validates the name of the target host:

```
PS /Users/anthony> Get-AGMLibHostID demo-sql-4

id       hostname   osrelease                                    appliancename applianceip  appliancetype
--       --------   ---------                                    ------------- -----------  -------------
43673548 demo-sql-4 Microsoft Windows Server 2019 (version 1809) sa-sky        172.24.1.180 Sky
```

The user validates the SQL instance name on the target host.  Because the user isn't sure about naming of the hostname  they used '~' to get a fuzzy search.  Because they couldn't remember the exact apptype for SQL instance, they again just used a fuzzy search for 'instance':

```
PS /Users/anthony> Get-AGMApplication -filtervalue "hostname~demo-sql-4&apptype~instance" | select pathname

pathname
--------
DEMO-SQL-4
```


The user runs a mount command specifying the source appid, target host and SQL Instance and DB name on the target:

```
PS /Users/anthony> New-AGMLibMSSQLMount -appid 5552336 -targethostname demo-sql-4 -label "test and dev made easy" -sqlinstance DEMO-SQL-4 -dbname avtest

```

The user finds the running job:

```
PS /Users/anthony> Get-AGMLibRunningJobs

jobname      jobclass   apptype         hostname                    appname               appid    appliancename startdate           progress targethost
-------      --------   -------         --------                    -------               -----    ------------- ---------           -------- ----------
Job_24358189 mount      SqlServerWriter hq-sql                      smalldb               5552336  sa-sky        2020-06-24 14:50:08       53 demo-sql-4
```

The user tracks the job to success:

```
PS /Users/anthony> Get-AGMLibFollowJobStatus Job_24358189

jobname      status  progress queuedate           startdate           duration
-------      ------  -------- ---------           ---------           --------
Job_24358189 running       95 2020-06-24 14:49:33 2020-06-24 14:50:08 00:01:30


jobname      status    message startdate           enddate duration
-------      ------    ------- ---------           ------- --------
Job_24358189 succeeded         2020-06-24 14:50:08         00:01:36
```

The user validates the mount exists:

```
PS /Users/anthony> Get-AGMLibActiveImage

imagename      apptype         hostname        appname appid    mountedhostname childappname appliancename consumedsize label
---------      -------         --------        ------- -----    --------------- ------------ ------------- ------------ -----
Image_24358189 SqlServerWriter hq-sql          smalldb 5552336  demo-sql-4      avtest       sa-sky                   0 test and dev made easy
```

The user works with the DB until it is no longer needed.

The user then unmounts the DB, specifying -d to delete the mount:

```
PS /Users/anthony> Remove-AGMMount Image_24358189 -d
```

The user confirms if the mount created a child app
```
PS /Users/anthony> Get-AGMLibApplicationID avtest

id       friendlytype hostname   appname appliancename applianceip  appliancetype managed
--       ------------ --------   ------- ------------- -----------  ------------- -------
52410625 SQLServer    demo-sql-4 avtest  sa-sky        172.24.1.180 Sky             False
```

The user deletes the child app:
```
PS /Users/anthony> Remove-AGMApplication 52410625
```

### SQL Test and Dev Image usage with point in time recovery

In this 'story' a user wants to mount a specific snapshot of a SQL DB to a host rolled to a specific point in time.   We start with an appname:

The user finds the appID for the source DB

```
PS /Users/anthony> Get-AGMLibApplicationID smalldb

id      friendlytype hostname appname appliancename applianceip  appliancetype managed
--      ------------ -------- ------- ------------- -----------  ------------- -------
5552336 SQLServer    hq-sql   smalldb sa-sky        172.24.1.180 Sky              True
261762  Oracle       oracle   smalldb sa-sky        172.24.1.180 Sky              True

```
We now get a list of images:

```
PS /Users/anthony> Get-AGMLibImageDetails 5552336

backupname            jobclass     consistencydate     endpit
----------            --------     ---------------     ------
Image_24351142        snapshot     2020-06-24 11:55:37 2020-06-25 15:07:16
Image_24386274        snapshot     2020-06-25 11:46:22 2020-06-25 15:07:16
```
We have two snapshots and logs as well.

The user runs a mount command specifying the source appid, target host and SQL Instance and DB name on the target as well as a recovery point in ISO 860 format and image name.  However they specify the wrong date, one earlier than the consistency point:

```
PS /Users/anthony> New-AGMLibMSSQLMount -imagename Image_24351142 -appid 5552336 -targethostname demo-sql-4 -label "test and dev made easy" -sqlinstance DEMO-SQL-4 -dbname avtest -recoverypoint "2020-06-23 16:00"

errormessage
------------
Specified recovery point 2020-06-23 16:00 is earlier than image consistency date 2020-06-24 11:55:37.  Specify an earlier image.

```
They fix the date and successfully run the command:
```
PS /Users/anthony> New-AGMLibMSSQLMount -imagename Image_24351142 -appid 5552336 -targethostname demo-sql-4 -label "test and dev made easy" -sqlinstance DEMO-SQL-4 -dbname avtest -recoverypoint "2020-06-24 16:00"
```


## SQL Instance Test and Dev Image usage

In this 'story' a user wants to mount two databases from the latest snapshot of a SQL Instance to a host.  Most aspects of the story are the same as above, however they need some more information to run their mount command.   They learn the App ID of the SQL Instance:

```
PS /Users/anthony> Get-AGMLibApplicationID  HQ-SQL

id      friendlytype hostname appname appliancename applianceip  appliancetype managed
--      ------------ -------- ------- ------------- -----------  ------------- -------
5534398 SqlInstance  hq-sql   HQ-SQL  sa-sky        172.24.1.180 Sky              True
```

We now learn the instance members:
```
PS /Users/anthony> Get-AGMApplicationInstanceMember 5534398

rule            : exclude
totaldb         : 9
includecount    : 4
excludecount    : 4
ineligiblecount : 1
ineligiblelist  : {@{id=5552336; appname=smalldb; apptype=SqlServerWriter; srcid=4808; sensitivity=0; systemdb=False; ispartofmemberrule=False; appstate=0}}
eligiblelist    : {@{id=5552340; appname=ReportServer; apptype=SqlServerWriter; srcid=4810; sensitivity=0; systemdb=False; ispartofmemberrule=True; appstate=0}, @{id=5552338; appname=ReportServerTempDB; apptype=SqlServerWriter;
                  srcid=4809; sensitivity=0; systemdb=False; ispartofmemberrule=True; appstate=0}, @{id=5552346; appname=master; apptype=SqlServerWriter; srcid=4813; sensitivity=0; systemdb=False; ispartofmemberrule=True; appstate=0},
                  @{id=50805022; appname=model; apptype=SqlServerWriter; srcid=23401122; sensitivity=0; systemdb=False; ispartofmemberrule=False; appstate=0}…}               
```

However the eligible list is not easy to read, so lets expand it and put it into a table.  This is much easier to read:

```
PS /Users/anthony> Get-AGMApplicationInstanceMember 5534398 | Select-Object -ExpandProperty eligiblelist | ft

id       appname            apptype         srcid    sensitivity systemdb ispartofmemberrule appstate
--       -------            -------         -----    ----------- -------- ------------------ --------
5552340  ReportServer       SqlServerWriter 4810               0    False               True        0
5552338  ReportServerTempDB SqlServerWriter 4809               0    False               True        0
5552346  master             SqlServerWriter 4813               0    False               True        0
50805022 model              SqlServerWriter 23401122           0    False              False        0
5552342  msdb               SqlServerWriter 4811               0    False               True        0
5552334  smalldb1           SqlServerWriter 4805               0    False              False        0
5552332  smalldb2           SqlServerWriter 4804               0    False              False        0
5552330  smalldb3           SqlServerWriter 4803               0    False              False        0
```
So now we know the names of the DBs inside our SQL instance, we just need to chose a Consistency group name  to hold them and any prefixe and sufffixes we want to use.  We then run our mount command like this:

```
PS /Users/anthony>  New-AGMLibMSSQLMount -appid 5534398 -targethostname demo-sql-5 -label "AV instance mount" -sqlinstance DEMO-SQL-5 -consistencygroupname avcg -dbnamelist "smalldb1,smalldb2" -dbnameprefix "testdev_" -dbnamesuffix "_av"
```

## Protecting and re-windind child-apps

In this story, the we create a child app of a SQL DB that is protected by an on-demand template.

First we create the child app.   There are several things about this command.   Firstly it does not specify an image ID, it will just use the latest snapshot.   It specifies the SLTID and SLPID to manage the child app.  This command was generated by just running New-AGMLibMSSQLMount in guided mode.  
```
New-AGMLibMSSQLMount -appid 884945 -mountapplianceid 1415071155  -label "avtest" -targethostid 655169 -sqlinstance "SYDWINSQL5" -dbname "avtestrp10" -sltid 6318469 -slpid 655697
```
We validate the child app was created:
```
PS /Users/anthonyv/Documents/github/AGMPowerLib> Get-AGMLibApplicationID avtestrp10

id            : 6403028
friendlytype  : SQLServer
hostname      : sydwinsql5
appname       : avtestrp10
appliancename : sydactsky1
applianceip   : 10.65.5.35
appliancetype : Sky
managed       : True
slaid         : 6403030
```
We run an on-demand snapshot of the child app (the mount) when we are ready to make that first bookmark:
```
PS /Users/anthonyv/Documents/github/AGMPowerLib> New-AGMLibImage -appid 6403028

jobname     status  queuedate           startdate
-------     ------  ---------           ---------
Job_9900142 running 2020-09-04 17:00:41 2020-09-04 17:00:41
```
The image is created quickly:
```
PS /Users/anthonyv/Documents/github/AGMPowerLib> Get-AGMLibLatestImage 6403028

appliance       : sydactsky1
hostname        : sydwinsql5
appname         : avtestrp10
appid           : 6403028
jobclass        : snapshot
backupname      : Image_9900142
id              : 6403125
consistencydate : 2020-09-04 17:01:06
endpit          :
sltname         : bookmarkOnDemand
slpname         : Local Only
policyname      : SnapOnDemand
```
We can now continue to use our development child-app in the knowledge we can re-wind to a known good point.    

If we need to re-wind, we simply run the following command, referencing the image ID:
```
Restore-AGMLibMount -imageid 6403125
```
We learn the jobname with this command:
```
Get-AGMLibRunningJobs | ft *
```
We then monitor the job, it runs quickly as its a rewind
```
PS /Users/anthonyv/Documents/github/AGMPowerLib> Get-AGMLibFollowJobStatus Job_9900239

jobname   : Job_9900239
status    : succeeded
message   : Success
startdate : 2020-09-04 17:03:47
enddate   : 2020-09-04 17:05:08
duration  : 00:01:20
```
We can then continue to work with our child apps, creating new snapshots or even new child apps using those snapshots.


# User Story - Creating new VMs

Actifio can store images of many kinds of virtual machines.  The two formats we are going to explore here are:

* System State images - where the image used to generate a new VM is created by the Actifio Connector using a system state backup.  The source system could be amongst many things:  an AWS EC2 instance, a GCP GCE Instance an Azure VM, a VMware VM or a physical machine.
* VMware VMs - where the image of the VMware VM is created by a VMware Snapshot.  We can use this image to make either a new VMware VM, or an image in other supported hypervisors, such as AWS, Azure and GCP.

There are several guided functions you can use to run or build a working command to mount these images:

* New-AGMLibAWSVM - to create a new AWS EC2 Instance
* New-AGMLibAzureVM - to create a new Azure VM
* New-AGMLibGCPVM - to create a new GCP Instance
* New-AGMLibSystemStateToVM - to create a new VMware VM from a system state image
* New-AGMLibVM - to create a new VMware VM from a VMware snapshot

There are three ways to use these functions:

1. Run the function in guided mode by just starting the function without options.   Use the function to build a typical mount.   The end result will be a command you can save to run later or one you can run right now.    Since the goal is to provide automation, the purpose of the guided mode is not for day to day use, but to help you learn the syntax of a working command.
1.  Having created a guided output command, you will note the command contains an imageID.   The problem with this is that images are not persistent (unless they are set to never expire).  Typically you would need to use some logic to learn a current image ID.   In this case, we would specify the image ID as a variable that is poroduced by a different function.  The command would look like this:  
    ```
    New-AGMLibGCPVM -imageid $imageid -vmname "avtest20" -gcpkeyfile "/Users/anthony/Downloads/actifio-sales-310-a95fd43f4d8b.json" -volumetype "SSD persistent disk" -projectid "project1" -regioncode "us-east4" -zone "us-east4-b" -network1 "default;sa-1;"
    ```
1.  The alternative to (2) above is to instead specify an appid and mountapplianceid.  The nice thing is that guided mode will supply these.   If you supply an imageid it is pointless supplying an appid and appliance ID since an image is always tied to an app and an appliance, but presuming we don't know the image ID at time of running the command and all we want is the more recent image on the specified appliance, then this command will work pefectecly.   The nice thing is you can now store this command to run later, knowing it will just use the latest available image at the time you run it.   Note that importing OnVault images before running it may be required.   Here is a typical command, notice the difference with (2) above:
    ```
    New-AGMLibGCPVM -appid 20933978 -mountapplianceid 1415033486 -vmname "avtest20" -gcpkeyfile "/Users/anthony/Downloads/actifio-sales-310-a95fd43f4d8b.json" -volumetype "SSD persistent disk" -projectid "project1" -regioncode "us-east4" -zone "us-east4-b" -network1 "default;sa-1;"
    ```

### Importing OnVault images

Prior to running your scripts you may want to import the latest OnVault images into your appliance.  Doing this requires only one command with two parameters like this:
```
Import-AGMOnVault -diskpoolid 20060633 -applianceid 1415019931 
```
Learn Appliance ID with (use the cklusterid value):
```
Get-AGMAppliance | select name,clusterid | sort-object name
```
Learn Diskpool ID with (use the ID field): 
```
Get-AGMDiskPool | where-object {$_.pooltype -eq "vault" } | select id,name | sort-Object name
```
You can as an alternative import a specific appid by learning the appid with this command (using the appname, in the example here: *smalldb*):
```
Get-AGMLibApplicationID smalldb
```
Then run a command like this (using the id of the app as appid): 
```
 Import-AGMOnVault -diskpoolid 20060633 -applianceid 1415019931 -appid 4788
```
Note you can also adds **-forget** to forget learned images, or **-owner** to take ownership of those images.

### Authentication details

During guided mode you will notice that for functions that expect authentication details, these details are not mirrored to the screen as you type them.   However for stored scripts this presents a problem.   The good news is that for four out of five functions this is handled quite cleanly: 

* New-AGMLibAWSVM - Rather than specify the account and secret key,  use the CSV file downloaded when you generate the key in the IAM panel.   You just need to specify the path and file name for that CSV.
* New-AGMLibAzureVM - Guided mode will not print the access credentials.  You will need to type them in later and store them securely.
* New-AGMLibGCPVM - This uses the JSON file downloaded from the GCP Cloud Console IAM panel.
* New-AGMLibSystemStateToVM - This uses stored credentials on the appliance.
* New-AGMLibVM - This uses stored credentials on the appliance.


# User Story - Ransomware recovery

There are many cases where you may want to mount many VMs in one hit.  A simple scenario is ransomware, where you are trying to find an uninfected or as yet unattacked (but infected) image for each production VM.   So lets mount as many images as we can as quickly as we can so we can start the recovery.

First we build an object that contains a list of images.  For this we can use:
```
$imagelist = Get-AGMLibImageRange
```
In this example we get all images of VMs created in the last day:
```
Get-AGMLibImageRange -apptype VMBackup -appliancename sa-sky -olderlimit 1
```
if we now that the last 24 hours is not going to be any good, we could use this (up to 3 days but not less than 1 day old):
```
Get-AGMLibImageRange -apptype VMBackup -appliancename sa-sky -olderlimit 3 -newerlimit 1
```
Learn your vcenter host ID and set id:
```
PS /Users/anthony/git/AGMPowerLib> Get-AGMHost -filtervalue "isvcenterhost=true" | select id,hostname,srcid

id      hostname                  srcid
--      --------                  -----
5552172 scvmm.sa.actifio.com      4661
5552150 hq-vcenter.sa.actifio.com 4460
5534713 vcenter-dr.sa.actifio.com 4371

PS /Users/anthony/git/AGMPowerLib> $vcenterid = 5552150
```
Now learn your ESXHost IDs and make a simple array.  We need to choose ESX hosts thatr have datastores in common, because we are going to round robin across the ESX hosts and datastores.
```
PS /Users/anthony/git/AGMPowerLib> Get-AGMHost -filtervalue "isesxhost=true&vcenterhostid=4460" | select id,hostname

id       hostname
--       --------
26534616 sa-esx8.sa.actifio.com
5552168  sa-esx6.sa.actifio.com
5552166  sa-esx5.sa.actifio.com
5552164  sa-esx1.sa.actifio.com
5552162  sa-esx2.sa.actifio.com
5552160  sa-esx4.sa.actifio.com
5552158  sa-esx7.sa.actifio.com

PS /Users/anthony/git/AGMPowerLib> $esxhostlist = @(5552166,5552168)
PS /Users/anthony/git/AGMPowerLib> $esxhostlist
5552166
5552168
```
Now make an array of datastores:
```
PS /Users/anthony/git/AGMPowerLib> $datastorelist = ((Get-AGMHost -id 5552166).sources.datastorelist | select-object name,freespace | sort-object name | Get-Unique -asstring | select name).name

PS /Users/anthony/git/AGMPowerLib> $datastorelist
IBM-FC-V3700
Pure
```
We can now fire our new command:
```
New-AGMLibMultiVM -imagelist $imagelist -vcenterid $vcenterid -esxhostlist $esxhostlist -datastorelist 
```
For uniqueness we have quite a few choices to generate VMs with useful names.   If you do nothing, then a numeric indicator will be added to each VM as a suffix.  Otherwise we can use:

* -prefix xxxx           :   where xxxx is a prefix
* -suffix yyyy           :   where yyyy is a suffix
* -c or -condatesuffix   :  which will add the consistency date of the image as a suffix
* -i  or -imagesuffix    :  which will add the image name of the image as a suffix

This will mount all the images in the list and round robin through the ESX host list and data store list.

If you don't specify a label, all the VMs will get the label **MultiVM Recovery**   This will let you easily spot your mounts by doing this:
```
$mountlist = Get-AGMLibActiveImage | where-object  {$_.label -eq "MultiVM Recovery"}
```
When you are ready to unmount them, run this script:
```
foreach ($mount in $mountlist.imagename)
{
Remove-AGMMount $mount -d
}
```

### esxhostid vs esxhostlist

You can just specify one esxhost ID with -esxhostid.   If you are using NFS datastore and you will let DRS rebalance laterm, this cna make things much faster

## datastore vs datastorelist

You can also specify a single datastore rather than a list.

## Editing your $Imagelist 

You could create a CSV of images, edit it and then convert that into an object.  This would let you delete all the images you don't want to recover, or create chunks to recover (say 20 images at a time)

In this example we grab 20 days of images:

```
Get-AGMLibImageRange -apptype VMBackup -appliancename sa-sky -olderlimit 20 | Export-Csv -Path .\images.csv
```

We now edit the CSV to remove images we don't want.   We then import what is left into our $imagelist:
```
$imagelist = Import-Csv -Path .\images.csv
```
