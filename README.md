# AGMPowerLib

A Powershell module that allows PowerShell users to issue complex API calls to Actifio Global Manager. This module contains what we call composite functions, these being complex combination of API endpoints.  

### Table of Contents
**[Prerequisites](#prerequisite)**<br>
**[Guided Wizards](#guided-wizards)**<br>
**[User Story: Database Mounts](#user-story-database-mounts)**<br>
**[User Story: SQL Instance Test and Dev Image usage](#user-story-sql-instance-test-and-dev-image-usage)**<br>
**[User Story: Protecting and re-winding child-apps](#user-story-protecting-and-re-winding-child-apps)**<br>
**[User Story: Running a workflow](#user-story-running-a-workflow)**<br>
**[User Story: Creating new VMs](#user-story-creating-new-vms)**<br>
**[User Story: Running on-demand jobs based on policy ID](#user-story-running-on-demand-jobs-based-on-policy-id)**<br>
**[User Story: File System multi-mount for Ransomware analysis](#user-story-file-system-multi-mount-for-ransomware-analysis)**<br>
**[User Story: VMware multi-mount](#user-story-vmware-multi-mount)**<br>
**[User Story: Microsoft SQL Mount and Migrate](#user-story-microsoft-sql-mount-and-migrate)**<br>
**[User Story: Persistent Disk Snapshots](#user-story-persistent-disk-snapshots)**<br>


## Prerequisites

This module requires AGMPowerCLI to already be installed.
Please visit this repo first:  https://github.com/Actifio/AGMPowerCLI
Once you have installed AGMPowerCLI, then come back here and install AGMPowerLib to get the composite functions.


### Install or Upgrade AGMPowerLib

Install from PowerShell Gallery:

```
Install-Module -Name AGMPowerLib
```

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

Many corporations do not allow access to or downloads from PowerShell gallery or even access to GitHub from Production Servers, so for these we offer the following process:

1.  From GitHub, use the Green Code download button to download the AGMPowerLib repo as a zip file.  Normally you would use the **Main** branch for this, but there is also a **dev** branch for development builds prior to promotion to Main.
1.  Copy the Zip file to the server where you want to install it
1.  For Windows, Right select on the zip file, choose  Properties and then use the **Unblock** button next to the message:  *This file came from another computer and might be blocked to help protect  your computer.*
1.  For Windows, now right select and use **Extract All** to extract the contents of the zip file to a folder.  It doesn't matter where you put the folder.  For Mac it should automatically unzip.  For Linux use the unzip command to unzip the folder.
1.  Now start PWSH and change directory to the AGMPowerLib-main directory that should contain our module files.   
1.  There is an installer file: **Install-AGMPowerLib.ps1** so run that with **./Install-AGMPowerLib.ps1**  
If it finds multiple installs, we strongly recommend you delete them all and run the installer again to have just one install.


If the install fails with this (which usually occurs if you didn't unblock the zip file):
```
PS C:\Users\av\Downloads\AGMPowerLib-main\AGMPowerLib-main> .\Install-AGMPowerLib.ps1
.\Install-AGMPowerLib.ps1: File C:\Users\av\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 cannot be loaded. 
The file C:\Users\av\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 is not digitally signed. 
You cannot run this script on the current system. For more information about running scripts and setting execution policy, see about_Execution_Policies at https://go.microsoft.com/fwlink/?LinkID=135170.
```
Then run this command:
```
Get-ChildItem .\Install-AGMPowerLib.ps1 | Unblock-File
```
Then re-run the installer.  The installer will unblock the remaining files.

## Guided Wizards

The following functions have guided wizards to help you create commands.   Simply run these commands without any options to start the wizard.   Once you have created a typical command, you can use it build more commands or automation.

#### Database mounts:
```
New-AGMLibContainerMount
New-AGMLibOracleMount
New-AGMLibMSSQLMount
```
##### Workflow mounts
```
Get-AGMLibWorkflowStatus
Start-AGMLibWorkflow
```
#### FileSystem Mounts:
```
New-AGMLibFSMount
```
#### New VM mounts:
```
New-AGMLibAWSVM
New-AGMLibAzureVM
New-AGMLibGCPVM
New-AGMLibSystemStateToVM
New-AGMLibVM 
New-AGMLibVMExisting 
```


## User Story: Database Mounts
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
Because applications can have images on multiple appliances, if we don't specify an Image name or Image ID, we need to tell AGM which appliance to use for the source image.   We do this specifying the clusterid of the relevant appliance with -mountapplianceid.   To learn the clusterids we run this command:
```
Get-AGMAppliance | select-object name,clusterid
```

The user then runs a mount command specifying the source appid, mountapplianceid, target host and SQL Instance and DB name on the target:

```
PS /Users/anthony> New-AGMLibMSSQLMount -appid 5552336 -mountapplianceid 1415071155 -targethostname demo-sql-4 -label "test and dev made easy" -sqlinstance DEMO-SQL-4 -dbname avtest

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

The user then un-mounts the DB, specifying -d to delete the mount:

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

### SQL DB mount of an Orphan image

Presuming we know the name of our orphan app and the host it once lived on.  Choose the backupname of the image you want by searching for the appname:

```
PS > get-agmimage -filtervalue appname=avdb1 | select id,host,consistencydate,backupname,jobclass | ft *

id      host                   consistencydate     backupname     jobclass
--      ----                   ---------------     ----------     --------
7397674 @{hostname=sydwinsql5} 2020-10-30 13:55:26 Image_10979893 snapshot
7397570 @{hostname=sydwinsql5} 2020-10-30 13:54:16 Image_10979874 snapshot
```

Now learn the host ID of the host we want to mount to using the hostname.  In this example we use a fuzzy search.

```
PS > get-agmhost -filtervalue hostname~sql5 | select hostname,id

hostname   id
--------   --
sydwinsql5 655169
```

Now if you don't know the instance names on that host, learn that:

```
PS > Get-AGMApplication -filtervalue "hostid=655169&apptype=SqlInstance" | select appname,apptype

appname             apptype
-------             -------
SYDWINSQL5\SYDWIN5C SqlInstance
SYDWINSQL5          SqlInstance
```

Now we build our mount command using the imagename, host ID of the target host, the SQL Instance name and the intended name on the target server.
```
New-AGMLibMSSQLMount -imagename Image_10979893 -targethostid 655169 -sqlinstance "SYDWINSQL5" -dbname "avtest9" -recoverdb true -userlogins false -recoverymodel "Same as source" -overwrite "no" -monitor
```
You will then get a job monitor because we specified -monitor.



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


## User Story: SQL Instance Test and Dev Image usage

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
So now we know the names of the DBs inside our SQL instance, we just need to chose a Consistency group name  to hold them and any prefixes and suffixes we want to use.  We then run our mount command like this:

```
PS /Users/anthony>  New-AGMLibMSSQLMount -appid 5534398 -targethostname demo-sql-5 -label "AV instance mount" -sqlinstance DEMO-SQL-5 -consistencygroupname avcg -dbnamelist "smalldb1,smalldb2" -dbnameprefix "testdev_" -dbnamesuffix "_av"
```

## User Story: Protecting and re-winding child apps

In this story, we create a child app of a SQL DB that is protected by an on-demand template.

First we create the child app.   There are several things about this command.   Firstly it does not specify an image ID, it will just use the latest snapshot.   It specifies the SLTID and SLPID to manage the child app.  This command was generated by running **New-AGMLibMSSQLMount** in guided mode.  
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
We can then continue to work with our child app, creating new snapshots or even new child apps using those snapshots.

# User Story: Running a workflow

Note there is no function to create Workflows, so continue to use AGM for this.   
There are two functions for workflows:

* Get-AGMLibWorkflowStatus
* Start-AGMLibWorkflow 

For both commands, you don't need any details, just run the command and a wizard will run.   You can use this to learn things like workflow IDs and App IDs so that you can then use these commands as part of automation.

We can start a workflow with a command like this:
```
Start-AGMLibWorkflow -workflowid 9932352
```
We can then run a refresh of this workflow with this command:
```
Start-AGMLibWorkflow -workflowid 9932352 -refresh
```
To find out the status of the workflow and follow the progress, use -m (for monitor mode) as it will follow the workflows progress till it stops running:
```
Get-AGMLibWorkflowStatus -workflowid 9932352 -m
```
We shoud see something like this:
```
status    : RUNNING
startdate : 2020-10-17 11:52:55
enddate   :
duration  : 00:00:03
result    :
jobtag    : avtestwf_momuser_1404389_9932352_10715728

status    : SUCCESS
startdate : 2020-10-17 11:52:55
enddate   : 2020-10-17 11:55:26
duration  : 00:02:31
result    :
jobtag    : avtestwf_momuser_1404389_9932352_10715728
```
If we want to see the results from the previous run, we can use -p (for previous) like this:
```
Get-AGMLibWorkflowStatus -workflowid 9932352 -p
```
If you want to find any jobs that were ran (or are running) by that workflow, use the job_tag like this:
```
Get-AGMJobStatus -filtervalue jobtag=avtestwf_momuser_1404389_9932352_10715570
```
For example:
```
PS /Users/anthonyv/Downloads> Get-AGMJobStatus -filtervalue jobtag=avtestwf_momuser_1404389_9932352_10715728 | select-object jobclass,status,startdate,enddate

jobclass    status    startdate           enddate
--------    ------    ---------           -------
reprovision running   2020-10-17 11:52:57  

PS /Users/anthonyv/Downloads> Get-AGMJobStatus -filtervalue jobtag=avtestwf_momuser_1404389_9932352_10715728 | select-object jobclass,status,startdate,enddate

jobclass    status    startdate           enddate
--------    ------    ---------           -------
reprovision succeeded 2020-10-17 11:52:57 2020-10-17 11:55:08
```

## User Story: Creating new VMs

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


## User Story: Running on-demand jobs based on policy ID

One way to create a semi air-gapped solution is to restrict access to the OnVault pool by using limited time windows that are user controlled.
If we create an OnVault or Direct2Onvault policy that never runs, meaning it is set to run everyday except everyday, then the policy will only run when manually requested.
We can then learn the policy ID and create a command to run it.

First learn the policy ID.  In this example the policy ID of the cloud job is 25627
```
PS /tmp/agmpowercli> Get-AGMLibPolicies | ft

sltid sltname       id    name        op    priority retention starttime endtime rpo
----- -------       --    ----        --    -------- --------- --------- ------- ---
25606 FSSnaps_RW_OV 25627 OndemandOV  cloud medium   14 days   19:00     18:50   24 hours
25606 FSSnaps_RW_OV 25607 DailySnap   snap  medium   7 days    00:00     23:59   24 hours
```
We now have what we need to build our command.
Before we begin we need to enable the service account we are going to use.  We then start the OnVault jobs like this:
```
PS /tmp/agmpowercli> Start-AGMLibPolicy -policyid 25627
Starting job for appid 20577 using cloud policy ID 25627 from SLT FSSnaps_RW_OV
Starting job for appid 6965 using cloud policy ID 25627 from SLT FSSnaps_RW_OV
```
We can then monitor them like this:
```
PS /tmp/agmpowercli> Get-AGMJob -filtervalue "policyname=OndemandOV" | select status,progress

status  progress
------  --------
running       97
running       98
```
Good logic would work like this:
1. Count the relevant apps.  In this example we have 2.
```
PS /tmp/agmpowercli> $appgrab = Get-AGMApplication -filtervalue "sltname=FSSnaps_RW_OV"
PS /tmp/agmpowercli> $appgrab.count
2
```
2. Count the current images.  We currently have 6 OnVault images.
```
PS /tmp/agmpowercli> $imagegrab = Get-AGMImage -filtervalue "sltname=FSSnaps_RW_OV&jobclass=OnVault"
PS /tmp/agmpowercli> $imagegrab.count
6
```
3. Run a new OnVault job.  We get two jobs started.
```
PS /tmp/agmpowercli> Start-AGMLibPolicy -policyid 25627
Starting job for appid 20577 using cloud policy ID 25627 from SLT FSSnaps_RW_OV
Starting job for appid 6965 using cloud policy ID 25627 from SLT FSSnaps_RW_OV
```
4.  Scan for running jobs until they all finish
```
PS /tmp/agmpowercli> Get-AGMJob -filtervalue "policyname=OndemandOV" | select status,progress

status             progress
------             --------
queued                    0
queued (readiness)        0

PS /tmp/agmpowercli> Get-AGMJob -filtervalue "policyname=OndemandOV" | select status,progress

status  progress
------  --------
running        2
running        2

PS /tmp/agmpowercli> Get-AGMJob -filtervalue "policyname=OndemandOV" | select status,progress

status    progress
------    --------
running         98
succeeded      100

PS /tmp/agmpowercli> Get-AGMJob -filtervalue "policyname=OndemandOV" | select status,progress

status progress
------ --------


PS /tmp/agmpowercli>

```
5. Count the images and ensure they went up by the number of apps.   Note that if expiration run at this time, this will confuse the issue.
You can see here we went from 6 to 8.
```
PS /tmp/agmpowercli> $imagegrab = Get-AGMImage -filtervalue "sltname=FSSnaps_RW_OV&jobclass=OnVault"
PS /tmp/agmpowercli> $imagegrab.count
8
PS /tmp/agmpowercli>
```

## User Story: File System multi-mount for Ransomware analysis

There are many cases where you may want to mount many filesystems in one hit.  A simple scenario is ransomware, where you are trying to find an uninfected or as yet unattacked (but infected) image for each production filesystem.   So lets mount as many images as we can as quickly as we can so we can find unaffected filesystems and start the recovery.

#### Building a list of images
First we build an object that contains a list of images.  For this we can use **Get-AGMLibImageRange** in a syntax like this, where in this example we get all images of filesystems created in the last day:
```
$imagelist = Get-AGMLibImageRange -apptype FileSystem -appliancename sa-sky -olderlimit 1
```
If we know that images created in the last 24 hours are all infected, we could use this (up to 3 days old but not less than 1 day old):
```
$imagelist = Get-AGMLibImageRange -apptype FileSystem -appliancename sa-sky -olderlimit 3 -newerlimit 1
```
We can also use the Template Name (SLT) to find our apps.  This is a handy way to separate apps since you can create as many SLTs as you like and use them as a unique way to group apps.
```
$imagelist = Get-AGMLibImageRange -sltname FSSnaps_RW_OV -olderlimit 3 -newerlimit 1
```

#### Editing your $Imagelist 

You could create a CSV of images, edit it and then convert that into an object.  This would let you delete all the images you don't want to recover, or create chunks to recover (say 20 images at a time)

In this example we grab 20 days of images:

```
Get-AGMLibImageRange -apptype FileSystem -appliancename sa-sky -olderlimit 20 | Export-Csv -Path .\images.csv
```

We now edit the CSV  we created **images.csv** to remove images we don't want.   We then import what is left into our $imagelist variable:
```
$imagelist = Import-Csv -Path .\images.csv
```
Now we have our image list, we can begin to create our recovery command.

#### Define our scanning host list
 
We need to define a single host to use as our mount target or an array of hosts.

```
PS /tmp/agmpowerlib> Get-AGMHost -filtervalue "hostname~mysql" | select id,hostname

id   hostname
--   --------
7376 mysqltarget
6915 mysqlsource

PS /tmp/agmpowerlib> $hostlist = @(7376,6915)
```
We could also define a specific host like this:
```
$hostid = 7376
```
#### Run our multi-mount command

We can now fire our new command using the settings we defined and our image list:
```
New-AGMLibMultiMount -imagelist $imagelist -hostlist $hostlist -mountpoint /tmp/
```
For uniqueness we have quite a few choices to generate mounts with useful names.   A numeric indicator will always be added to each mountpoint as a suffix.  Optionally we can use any of the following.   They will be added in the order they are listed here:

* -h or hostnamesuffix   :  which will add the host name of the image to the mountpoint
* -a or -appnamesuffix   :  which will add the appname of the image to the mountpoint
* -i  or -imagesuffix    :  which will add the image name of the image to the mountpoint
* -c or -condatesuffix   :  which will add the consistency date of the image to the mountpoint


This will mount all the images in the list and round robin through the host list.

If you don't specify a label, all the image will get the label **MultiFS Recovery**   This will let you easily spot your mounts by doing this:
```
$mountlist = Get-AGMLibActiveImage | where-object  {$_.label -eq "MultiFS Recovery"}
```
When you are ready to unmount them, run this script:
```
foreach ($mount in $mountlist.imagename)
{
Remove-AGMMount $mount -d
}
```
## User Story: VMware multi-mount

There are many cases where you may want to mount many VMs in one hit.  A simple scenario is ransomware, where you are trying to find an uninfected or as yet unattacked (but infected) image for each production VM.   So lets mount as many images as we can as quickly as we can so we can find unaffected VMs and start the recovery.

### Building a list of images
First we build an object that contains a list of images.  For this we can use Get-AGMLibImageRange in a synytax like this:
```
$imagelist = Get-AGMLibImageRange
```
In this example we get all images of VMs created in the last day:
```
$imagelist = Get-AGMLibImageRange -apptype VMBackup -appliancename sa-sky -olderlimit 1
```
If we know that images created in the last 24 hours are all infected, we could use this (up to 3 days old but not less than 1 day old):
```
$imagelist = Get-AGMLibImageRange -apptype VMBackup -appliancename sa-sky -olderlimit 3 -newerlimit 1
```
We can also use the Template Name (SLT) to find our apps.  This is a handy way to separate apps since you can create as many SLTs as you like and use them as a unique way to group apps.
```
$imagelist = Get-AGMLibImageRange -sltname FSSnaps_RW_OV
```

### Editing your $Imagelist 

You could create a CSV of images, edit it and then convert that into an object.  This would let you delete all the images you don't want to recover, or create chunks to recover (say 20 images at a time)

In this example we grab 20 days of images:

```
Get-AGMLibImageRange -apptype VMBackup -appliancename sa-sky -olderlimit 20 | Export-Csv -Path .\images.csv
```

We now edit the CSV  we created **images.csv** to remove images we don't want.   We then import what is left into our $imagelist variable:
```
$imagelist = Import-Csv -Path .\images.csv
```
Now we have our image list, we can begin to create our recovery command.

### Define our VMware environment 
 
First we learn our vcenter host ID and set id:
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

### Run our multi-mount command

We can now fire our new command using the VMware settings we defined and our image list:
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

#### esxhostid vs esxhostlist

You can just specify one esxhost ID with -esxhostid.   If you are using NFS datastore and you will let DRS rebalance later, this can make things much faster

#### datastore vs datastorelist

You can also specify a single datastore rather than a list.




## User Story: Microsoft SQL Mount and Migrate

In this user story we are going to use SQL Mount and Migrate to move an Actifio Mount back to server disk

### Create the mount

First we create the mount.  In this example we ran **New-AGMLibMSSQLMount** to build a command.
The final command looks like this:
```
New-AGMLibMSSQLMount -appid 884945 -mountapplianceid 1415071155 -label "test1" -targethostid 655169 -sqlinstance "SYDWINSQL5" -dbname "avtest77"
```

Rather than learn the image ID, we can store the appid and mount appliance ID and then let AGM find the latest snapshot:
```
-appid 884945 -mountapplianceid 1415071155
```
We set a label.  This is optional but a very good idea on every mount:
```
-label "test1"
```
We set the target host ID and target SQL instance on that host:
```
-targethostid 655169 -sqlinstance "SYDWINSQL5"
```
We set the DB name for the mounted DB.
```
-dbname "avtest77"
```

### Check the mount
Once the mount has been created, we are ready to start the migrate.   We can check our mount with:  **Get-AGMLibActiveImage**

### Start the migrate

We run **New-AGMLibMSSQLMigrate** to build our migrate command.   The final command looks like this:

```
New-AGMLibMSSQLMigrate -imageid 6859821 -files -restorelist "SQL_smalldb.mdf,D:\Data,d:\avtest1;SQL_smalldb_log.ldf,E:\Logs,e:\avtest1"
```
To break down this command:
* This starts a migrate with default copy thread of 4 and default frequency set to 24 hours for ImageID 6859821.   We could have set thread count and frequency with syntax like:  **-copythreadcount 2 -frequency 2**
* Files will be renamed to match the new database name because we didn't specify:  **-dontrenamedatabasefiles**
* Because **-files** was specified, the **-restorelist** must contain the file name, the source location and the targetlocation.
* Each file is separated by a semicolon,  the three fields for each file are comma separated.
* In this example, the file **SQL_smalldb.mdf** found in **D:\Data** will be migrated to **d:\avtest1**
* In this example, the file **SQL_smalldb_log** found in **E:\Logs** will be migrated to **e:\avtest1**
* The order of the fields must be **filename,sourcefolder,targetfolder** so for two files **filename1,source1,target1;filename2,source2,target2**

We could have specified volume migration rather than file migration, or we could have not specified either and let the files go back to their original locations (provided those locations exist).

### Change migrate settings

To change migrate settings we can run:  **Set-AGMLibMSSQLMigrate** and follow the prompts.  Or we can use syntax like this:
```
Set-AGMLibMSSQLMigrate -imageid 6860452 -copythreadcount 2 -frequency 2
```
This syntax sets the copy threads to 2 and the frequency to 2 hours for Image ID 6860452.   You can learn the image ID with **Get-AGMLibActiveImage -i** or **Set-AGMLibMSSQLMigrate**
This command is the same as using *Update Migration Frequency* in the Active Mounts panel of AGM.
You can check the migration settings with a command like this:
```
PS /AGMPowerLib> Get-AGMImage -id 6859821 | select-object migrate-frequency,migrate-copythreadcount,migrate-configured

migrate-frequency migrate-copythreadcount migrate-configured
----------------- ----------------------- ------------------
               24                       4               True
```

### Cancel the migrate 

If we decide to cancel the migrate we can run this command:
```
Remove-AGMMigrate -imageid 6860452
```
You can learn the image ID with **Get-AGMLibActiveImage -i** or **Set-AGMLibMSSQLMigrate**
This command is the same as using *Cancel Migration* in the Active Mounts panel of AGM.

### Run an on-demand migration job

The frequency you set will determine how often migrate jobs are run.   You can run on-demand migrations with:
```
Start-AGMMigrate -imageid 56072427 
```
This runs a migration job for Image ID 56072427.  You can learn the image ID with **Get-AGMLibActiveImage -i** or **Set-AGMLibMSSQLMigrate**
This command is the same as using *Run Migration Job Now* in the Active Mounts panel of AGM.

You can monitor this job with this command.  We need to know the App ID of the source application.  It will show both running and completed jobs
```
/Users/anthonyv/Documents/github/AGMPowerLib> get-agmjobstatus -filtervalue "jobclass=Migrate&appid=884945" | select-object status,startdate,enddate | sort-object startdate

status    startdate           enddate
------    ---------           -------
succeeded 2020-10-09 14:41:55 2020-10-09 14:42:15
succeeded 2020-10-09 14:51:58 2020-10-09 14:52:19
running   2020-10-09 14:54:55
```

### Run a finalize job
When you are ready to switch over, we need to run a finalize with this job:    
```
Start-AGMMigrate -imageid 56072427 -finalize
```
This command runs a Finalize job for Image ID 56072427. You can learn the image ID with **Get-AGMLibActiveImage -i** or **Set-AGMLibMSSQLMigrate**
This command is the same as using *Finalize Migration* in the Active Mounts panel of AGM.

You can monitor this job with this command.  We need to know the App ID of the source application.  It will show both running and completed jobs
```
/Users/anthonyv/Documents/github/AGMPowerLib> get-agmjobstatus -filtervalue "jobclass=Finalize&appid=884945" | select-object status,startdate,enddate | sort-object startdate

status    startdate           enddate
------    ---------           -------
succeeded 2020-10-09 15:02:15 2020-10-09 15:04:06
```

## User Story: Persistent Disk Snapshots

In this user story we are going to use Persistent Disk Snapshots to create a new GCE Instance.

### Creating a single GCE Instance from Snapshot

To learn which Applications are suitable use this command:
```
Get-AGMApplication -filtervalue "apptype=GCPInstance&managed=True" | select id,appname
```
To learn which Cloud Credentials are available use this command (use the srcid as the credential ID):
```
Get-AGMCredential
```
To learn the image ID or image name, you could use this command:
```
Get-AGMImage -filtervalue "apptype=GCPInstance&jobclass=snapshot" | select appname,id,name,consistencydate,diskpool | ft
```
There are many parameters that need to be supplied:
```
-appid           The application ID of the source GCP Instance you want to mount.  If you use this you don't need to specify an image ID or name.   It will use the latest snapshot of that application.
-imageid         You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image)
-imagename       You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image)
-credentialid    Learn this with Get-AGMCredential.  The credentialid is the srcid.
-serviceaccount  The service account that is being used to request the instance creation.  This is optional.  Otherwise it will use the account from the cloud credential
-projectname     This is the unique Google Project name
-zone            This is the GCP Zone such as: australia-southeast1-c
-instancename    This is the name of the new instance that will be created.   It needs to be unique in that project
-machinetype     This is the GCP instance machine type such as:  e2-micro
-networktags     Comma separate as many tags as you have, for instance:   -networktags "http-server,https-server"   
-labels          Labels are key value pairs.   Separate key and value with colons and each label with commas.   For example:   -labels "dog:cat,sheep:cow"
-nic0network     The network name in URL format for nic0
-nic0subnet      The subnet name in URL format for nic0
-nic0externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic0 is 'none'
-nic0internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic0 will be auto assigned.   
-poweronvm       By default the new GCE Instance will be powered on.   If you want it to be created but left powered off, then specify: -poweronvm false
                    There is no need to specify: -poweronvm true 
```
Optionally you can request a second NIC:
```
-nic1network     The network name in URL format for nic1
-nic1subnet      The subnet name in URL format for nic1
-nic1externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic1 is 'none'
-nic1internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic1 will be auto assigned.  
```
This brings us to a command like this one:
```
New-AGMLibGCPInstance -imageid 56410933 -credentialid 1234 -zone australia-southeast1-c -projectname myproject -instancename avtest21 -machinetype e2-micro -networktags "http-server,https-server" -labels "dog:cat,sheep:cow" -nic0network "https://www.googleapis.com/compute/v1/projects/projectname/global/networks/default" -nic0subnet "https://www.googleapis.com/compute/v1/projects/projectname/regions/australia-southeast1/subnetworks/default" -nic0externalip auto -nic0internalip "10.152.0.200" -poweronvm false
```

### Performing a multi-mount from file

We can take our command to create a new GCP VM and store the parameters needed in a CSV file
Here is an example:
```
appid,credentialid,projectname,zone,instancename,machinetype,serviceaccount,networktags,labels,nic0network,nic0subnet,nic0externalip,nic0internalip,nic1network,nic1subnet,nic1externalip,nic1internalip,poweronvm
35590,28417,prodproject1,australia-southeast1-c,tinym,e2-micro,,"http-server,https-server","dog:cat,sheep:cow",https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/default,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/default,,, ,,,,TRUE
51919,28417,prodproject1,australia-southeast1-c,mysqlsourcem,e2-medium,,,,https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/default,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/default,auto,,https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/actifioanz,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/australia,auto,10.186.0.200,
36104,28417,prodproject1,australia-southeast1-c,mysqltargetm,e2-medium,,,,https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/default,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/default,,10.152.0.200,,,,,TRUE
```
We can then run the command like this:
```
New-AGMLibGCPInstanceMultiMount -instancelist recoverylist.csv
```
This will load the contents of the file recoverylist.csv and use it to run multiple **New-AGMLibGCPInstance** jobs
 
What is not supported right now:
1)  Using different storage classes
2)  Specifying more than one internal IP per subnet.
    
If you need either of these, please open an issue in Github.


### Managing the mounted GCE Instance 

```
PS /tmp/agmpowercli> Get-AGMLibActiveImage

imagename        : Image_0021181
apptype          : GCPInstance
appliancename    : avwlab2sky
hostname         : windows
appname          : windows
mountedhost      : avrecovery4
allowedip        :
childappname     : avrecovery4
consumedsize_gib : 0
daysold          : 0
label            :
imagestate       : Mounted
```
We have two choices 

1.Unmount and delete. This command deletes the mounted image record on the Actifio GO side and the GCE Instance on the GCP side.

```
PS /tmp/agmpowercli> Remove-AGMMount Image_0021181  -d
PS /tmp/agmpowercli>
```
2. Preserve the image on GCP side. This command deletes the mounted image record on Actifio GO side but leaves the GCE Instance on the GCP side. In the AGM GUI this is called forgetting the image

```
PS /tmp/agmpowercli> Remove-AGMMount Image_0021181  -d -p
PS /tmp/agmpowercli>
```
