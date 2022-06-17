# AGMPowerLib

A Powershell module that allows PowerShell users to issue complex API calls to Actifio Global Manager. This module contains what we call composite functions, these being complex combination of API endpoints.  

### Table of Contents
**[Prerequisites](#prerequisites)**<br>
**[Install or upgrade AGMPowerLib](#install-or-upgrade-agmpowerlib)**<br>
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
**[User Story: Microsoft SQL Multi Mount and Migrate](#user-story-microsoft-sql-multi-mount-and-migrate)**<br>
**[User Story: SAP HANA Database Mount](#user-story-sap-hana-database-mount)**<br>
**[User Story: Auto adding GCE Instances and protecting them with tags](#user-story-auto-adding-gce-instances-and-protecting-them-with-tags)**<br>
**[User Story: Creating GCE Instance from PD Snapshots](#user-story-creating-gce-instance-from-pd-snapshots)**<br>
**[User Story: GCE Disaster Recovery using GCE Instance PD Snapshots](#user-story-gce-disaster-recovery-using-gce-instance-pd-snapshots)**<br>
**[User Story: Creating GCE Instance from VMware Snapshots](#user-story-creating-gce-instance-from-vmware-snapshots)**<br>
**[User Story: GCE Disaster Recovery using VMware VM Snapshots](#user-story-gce-disaster-recovery-using-vmware-vm-snapshots)**<br>
**[User Story: Importing and Exporting AGM Policy Templates](#user-story-importing-and-exporting-agm-policy-templates)**<br>
**[Contributing](#contributing)**<br>
**[License](#license)**<br>

## Prerequisites

This module requires AGMPowerCLI to already be installed.
Please visit this repo first:  https://github.com/Actifio/AGMPowerCLI
Once you have installed AGMPowerCLI, then come back here and install AGMPowerLib to get the composite functions.


## Install or upgrade AGMPowerLib

Install from PowerShell Gallery:

```
Install-Module -Name AGMPowerLib
```

### Upgrades using PowerShell Gallery

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

### Manual install

Many corporations do not allow access to or downloads from PowerShell gallery or even access to GitHub from Production Servers, so for these we offer the following process:

1.  From GitHub, use the Green Code download button to download the AGMPowerLib repo as a zip file.  Normally you would use the **Main** branch for this, but there is normally a development branch for the next planned version prior to promotion to Main, so if the version of Main is 0.0.0.49 look for a branch called 0.0.0.50  
1.  Copy the Zip file to the server where you want to install it
1.  For Windows, Right select on the zip file, choose  Properties and then use the **Unblock** button next to the message:  *This file came from another computer and might be blocked to help protect  your computer.*
1.  For Windows, now right select and use **Extract All** to extract the contents of the zip file to a folder.  It doesn't matter where you put the folder.  For Mac it should automatically unzip.  For Linux use the unzip command to unzip the folder. 
1.  Now start PWSH and change directory to the AGMPowerLib-main directory that should contain our module files.   
1.  There is an installer file: **Install-AGMPowerLib.ps1** so run that with **./Install-AGMPowerLib.ps1**  
If it finds multiple installs, we strongly recommend you delete them all and run the installer again to have just one install.

For Download you could also use this:
```
wget https://github.com/Actifio/AGMPowerLib/archive/refs/heads/main.zip
pwsh
Expand-Archive ./main.zip
./main/AGMPowerLib-main/Install-AGMPowerLib.ps1
rm main.zip
rm -r main
```

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

#### Silent Install

You can run a silent install by adding **-silentinstall** or **-silentinstall0**

* **-silentinstall0** or **-s0** will install the module in 'slot 0'
* **-silentinstall** or **-s** will install the module in 'slot 1' or in the same location where it is currently installed
* **-silentuninstall** or **-u** will silently uninstall the module.   You may need to exit the session to remove the module from memory

By slot we mean the output of **$env:PSModulePath** where 0 is the first module in the list, 1 is the second module and so on.
If the module is already installed, then if you specify **-silentinstall** or **-s** it will reinstall in the same folder.
If the module is not installed, then by default it will be installed into path 1
```
PS C:\Windows\system32>  $env:PSModulePath.split(';')
C:\Users\avw\Documents\WindowsPowerShell\Modules <-- this is 0
C:\Program Files (x86)\WindowsPowerShell\Modules <-- this is 1
PS C:\Windows\system32>
```
Or for Unix:
```
PS /Users/avw> $env:PSModulePath.Split(':')
/Users/avw/.local/share/powershell/Modules    <-- this is 0
/usr/local/share/powershell/Modules           <-- this is 1
```
Here is an example of a silent install:
```
PS C:\Windows\system32> C:\Users\avw\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 -silentinstall 
Detected PowerShell version:    5
Downloaded AGMPowerLib version: 0.0.0.35
Installed AGMPowerLib version:  0.0.0.35 in  C:\Program Files (x86)\WindowsPowerShell\Modules\AGMPowerLib\
```
Here is an example of a silent upgrade:
```
PS C:\Windows\system32> C:\Users\avw\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 -silentinstall 
Detected PowerShell version:    5
Downloaded AGMPowerLib version: 0.0.0.34
Found AGMPowerLib version:      0.0.0.34 in  C:\Program Files (x86)\WindowsPowerShell\Modules\AGMPowerLib
Installed AGMPowerLib version:  0.0.0.35 in  C:\Program Files (x86)\WindowsPowerShell\Modules\AGMPowerLib
PS C:\Windows\system32>
```

#### Silent Uninstall

You can uninstall the module silently by adding **-silentuninstall** or **-u**  to the Install command.  



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
New-AGMLibVMExisting 
```
#### New GCE Instances:
```
New-AGMLibGCEConversion
New-AGMLibGCPInstance
```
#### New Other VMs
```
New-AGMLibAWSVM
New-AGMLibAzureVM
```
#### New VMWave VMs:
```
New-AGMLibSystemStateToVM
New-AGMLibVM 
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

Now since this user story relies on running specific policies for specific groups of apps, we need a way to group them.
There are two ways to achieve this:

* Using unique Templates for each group
* Using LogicalGroups to group your apps.   This is the recommended method.

Once we have done this, then we can use **Start-AGMLibPolicy** to run a job against all apps either for one policy or in one logical group (or both).
So just run the command and follow the prompts to build your command:
```
Start-AGMLibPolicy
```
We then run our command, for instance:
```
PS > Start-AGMLibPolicy -policyid 6393 -backuptype dblog
Starting job for hostname: mysqlsource   appname: mysqlsource   appid: 51919 using: snap policyID: 6393 from SLTName: PDSnaps
Starting job for hostname: mysqltarget   appname: mysqltarget   appid: 36104 using: snap policyID: 6393 from SLTName: PDSnaps
Starting job for hostname: tiny   appname: tiny   appid: 35590 using: snap policyID: 6393 from SLTName: PDSnaps
PS >
```
We can then monitor the jobs like this:
```
PS /tmp/agmpowercli> Get-AGMJob -filtervalue "policyname=OndemandOV" | select status,progress

status  progress
------  --------
running       97
running       98
```
Your logic would work like this:
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

There is a composite function that is designed to help you find all the commands.   You can start this by running:  
```
Start-AGMLibRansomwareRecovery
```

### Stopping the Scheduler and/or expiration 

Prior to beginning recovery efforts you may want to stop the scheduler and expiration on large numbers of Apps or even your whole environment.
If you created Logical Groups this is one convenient way to manage this.   
There are two commands you can use:

* Get-AGMLibSLA      This command will list the Scheduler and Expiration status for all your apps, or if you use -appid or -slaid, for a specific app
* Set-AGMLibSLA      This command will let you set the scheduler or Expiration status for all your apps, specific apps or specific Logical Groups.

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
#### Updating Labels
We can use the following command to update the Label of a specific image:
```
Set-AGMImage
```
However we could update a large number of images with this command:
```
Set-AGMLibImage
```
## User Story: VMware multi-mount

There are many cases where you may want to mount many VMs in one hit.  A simple scenario is ransomware, where you are trying to find an uninfected or as yet unattacked (but infected) image for each production VM.   So lets mount as many images as we can as quickly as we can so we can find unaffected VMs and start the recovery.

There is a composite function that is designed to help you find all the commands.   You can start this by running:  
```
Start-AGMLibRansomwareRecovery
```


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

## User Story: Microsoft SQL Multi Mount and Migrate

In this user story we are going to use SQL Mount and Migrate to move an Actifio Mount back to server disk but we are going to run multiple mounts and migrates in a single pass using a CSV file

This video also documents the process:   https://youtu.be/QX5Sn3XHbCM

### Create the CSV sourcefile

The easiest way to create the CSV file is to run **New-AGMLibMSSQLMount** and take the option to output a CSV file at the end.

Once you have the file then edit it to add additional databases.  
* If you don't know the App ID, then specify the AppName (provided it is unique)
* If you don't know the target host ID, then specify the expected TaregtHostName (provided it is unique)
* If the target host doesn't exist, but you know what the target instance name will be, then make sure to specify **true** in the discovery column

Here is an example of a file:
```
appid,appname,imagename,imageid,mountapplianceid,targethostid,targethostname,sqlinstance,recoverypoint,recoverymodel,overwrite,label,dbname,consistencygroupname,dbnamelist,dbrenamelist,dbnameprefix,dbnamesuffix,recoverdb,userlogins,username,password,base64password,mountmode,mapdiskstoallesxhosts,mountpointperimage,sltid,slpid,discovery,perfoption,migrate,copythreadcount,frequency,dontrenamedatabasefiles,volumes,files,restorelist
,WINDOWS\SQLEXPRESS,,,143112195179,,win-target,WIN-TARGET\SQLEXPRESS,,Same as source,no,sqlinst1,,avcg1,,"model,model1;CRM,crm1",,,TRUE,FALSE,,,,,,,,,,,yes,4,1,,,,
```

### Create the CSV runfile

Where the source file needs to exist before you start,  the runrile will be created the first time you run **New-AGMLibMSSQLMulti** by specifying the name of a new file that doesnt yet exist.
The idea is that you will use this file throughout one DR or test event.   Once all databases are finalized then you can delete the runfile and start your next test using a a new file

### Checking image state
At any point in the process, we use **-checkimagestate** to validate whether our mounts exist.  
```
New-AGMLibMSSQLMulti -sourcefile recoverylist.csv  -runfile rundate22052022.csv -checkimagestate
```
The first time you run this command, the output will look like this:
```
id                 :
appname            : WINDOWS\SQLEXPRESS
targethostname     : win-target
childapptype       : ConsistencyGroup
childappname       : avcg1
label              : sqlinst1
previousimagestate :
currentimagestate  : NoMountedImage
```
* id is blank because there is no image yet created by a mount
* previousimagestate is blank because there is no image
* currentimagestate says NoMountedImage because there is no image

### Running the multi mount.
We start all the mounts at once with this command:
```
New-AGMLibMSSQLMulti -sourcefile recoverylist.csv  -runfile rundate22052022.csv -runmount
```
This will run multiple New-AGMLibMSSQLMount jobs.  If run twice, any collisions with existing mounts will not run. 
This means if a mount fails, after you resolve the cause of the issue you can just run the same command again without interfering with existing mounts.
After you run **New-AGMLibMSSQLMulti**  with **-runmount** then check the state with **-checkimagestate**

We expect it to initially show this, where id is still blank, but previousimagestate is telling you a mount was started.
```
id                 :
appname            : WINDOWS\SQLEXPRESS
targethostname     : win-target
childapptype       : ConsistencyGroup
childappname       : avcg1
label              : sqlinst1
previousimagestate : MountStarted
currentimagestate  : NoMountedImage
```
Once the mount job completes we will see this, where the ID is now known and currentimagestate is mounted.
```
id                 : 82789
appname            : WINDOWS\SQLEXPRESS
targethostname     : win-target
childapptype       : ConsistencyGroup
childappname       : avcg1
label              : sqlinst1
previousimagestate : MountStarted
currentimagestate  : Mounted
```
If you run the **-runmount** again, the existing mounts will be unaffected, but previousimagestate will change to: *MountFailed: mount is unsuccessful due to duplicate application on the same host/instance not allowed:*

### Starting the migration
Once all our images are mounted, we can start migrating.   If you run this command with some mounts still running, then migration will only start on those mounts that are ready and you will need to run startmigration again.
```
New-AGMLibMSSQLMulti -sourcefile recoverylist.csv -runfile rundate22052022.csv -startmigration
```
This will start migrate jobs for any SQL Db where the migrate field is set to true.
When you check after migrate has been requested you will see this, where previousimagestate and currentimagestate both say MigrateStarted:
```
id                 : 82789
appname            : WINDOWS\SQLEXPRESS
targethostname     : win-target
childapptype       : ConsistencyGroup
childappname       : avcg1
label              : sqlinst1
previousimagestate : MigrateStarted
currentimagestate  : MigrateStarted
```
Once the first migrate job has finished we will see this where currentimagestate is FinalizeEligible
```
id                 : 82789
appname            : WINDOWS\SQLEXPRESS
targethostname     : win-target
childapptype       : ConsistencyGroup
childappname       : avcg1
label              : sqlinst1
previousimagestate : MigrateStarted
currentimagestate  : FinalizeEligible
```
We can run additional migrate jobs (in addition to the scheduled ones), with this command:
```
New-AGMLibMSSQLMulti -sourcefile recoverylist.csv -runfile rundate22052022.csv -runmigration
```
If you use -runmigration without having first run -startmigration then nothing will happen.

### Starting the finalize
This last option may not be desirable in all cases.  A finalize is disruptive while the switch is made.   You may wish to run this last step one by one using the GUI.  Note if you need multiple finalize jobs per host, you need to run them one at a time.   This might mean running **-finalizemigration** multiple times.
```
New-AGMLibMSSQLMulti -sourcefile recoverylist.csv -runfile rundate22052022.csv -finalizemigration
```
After running the command you will initially see this, where previousimagestate is FinalizeStarted.
```
id                 : 82789
appname            : WINDOWS\SQLEXPRESS
targethostname     : win-target
childapptype       : ConsistencyGroup
childappname       : avcg1
label              : sqlinst1
previousimagestate : FinalizeStarted
currentimagestate  : FinalizeEligible
```
Once finalize is finished you will see this, where currentimagestate is ImageNotFound.  This is normal because at the end of the finalize the mount gets deleted.    Once you see this, validate the DB on the target host and you are complete.
```
id                 : 82789
appname            : WINDOWS\SQLEXPRESS
targethostname     : win-target
childapptype       : ConsistencyGroup
childappname       : avcg1
label              : sqlinst1
previousimagestate : FinalizeStarted
currentimagestate  : ImageNotFound
```
## User Story: SAP HANA Database Mount

In this 'story' a user wants to mount a HANA database from the latest snapshot of a HANA Instance (HDB) to a host. Most aspects of the story are the same as above, however they need some more information to run their mount command. They learn the App ID of the HANA database where 'act' is the name of the HANA database.
```
PS /Users/jeffoconnor> Get-AGMLibApplicationID act |ft

id     friendlytype hostname   hostid appname appliancename applianceip applianceid  appliancetype managed
--     ------------ --------   ------ ------- ------------- ----------- -----------  ------------- -------
577110 SAPHANA      coe-hana-1 577093 act     sky1          10.60.1.7   141767697828 Sky              True
```
So now we know the id of the Database inside our HANA instance, we just need to specify the HANA user store key (userstorekey) that has rights to recover the database on the target host (targethostname), a new database SID (dbsid) to use, and lastly to specify a target host filesystem mount point (mountpointperimage) for the HANA instance to run from. We then run our mount command like this:

```
PS /Users/jeffoconnor> New-AGMLibSAPHANAMount -appid 577110 -targethostname coe-hana-2 -dbsid "TGT" -userstorekey "ACTBACKUP" -mountpointperimage "/tgt" -label "Test HANA database"
```

## User Story: Auto adding GCE Instances and protecting them with tags

If we are onboarding large numbers of GCE Instances or we want to auto protect new instances using automation, we can use a function called: **New-AGMLibGCEInstanceDiscovery**

This function needs a CSV file as input to supply the following data to the function:

* **credentialid**  This is used to determine which stored credential is used to connect to Google Cloud. Learn this by running Get-AGMLibCredentialSrcID
* **applianceid**  This is used to determine which backup appliance will manage the new GCE Instance. Learn this by running Get-AGMLibCredentialSrcID
* **project**  this is the project where we are going to look for new GCE Instances
* **zone** this is the zone where we are going to look for new GCE Instances

So if you have two projects, then ensure the credential you have added as a Cloud Credential has been added to both projects as a service account in IAM and then add a line in the CSV for each zone in that project where you want to search.  This does mean if you add new zones to your project you will need to update the CSV to search in those zones.
An example CSV file is as follows:
```
credentialid,applianceid,project,zone
6654,143112195179,avwarglab1,australia-southeast1-c
6654,143112195179,avwarglab1,australia-southeast2-a
6654,143112195179,avwarglab1,australia-southeast2-b
```
When you run  **New-AGMLibGCEInstanceDiscovery** you have to specify one of these two choices:
* **-nobackup**  This will add all new GCE Instances it finds without protecting them
* **-backup**  This will add  all new GCE Instances it finds and for each Instance it will look for a label called **googlebackupplan** (or a label you specify with **-usertag**)  If the value for that label is the name of an existing policy template, it will automatically protect that instance using that template

An example run is as follows.  In the first zone, no new instances were found.  In the second zone, 3 were found and two protected.   A second run is made on each zone where more than 50 instances need to be processed (since we process 50 at a time).  The third zone had no new VMs.   
```
> New-AGMLibGCEInstanceDiscovery -discoveryfile ./disco.csv -backup

count                : 0
totalcount           : 0
credentialid         : 6654
applianceid          : 143112195179
project              : avwarglab1
zone                 : australia-southeast1-c
newgceinstances      : 0
newgceinstancebackup : 0

count                : 3
items                : {@{vm=}, @{vm=}, @{vm=}}
totalcount           : 3
credentialid         : 6654
applianceid          : 143112195179
project              : avwarglab1
zone                 : australia-southeast2-a
newgceinstances      : 3
newgceinstancebackup : 2

count                : 0
totalcount           : 0
credentialid         : 6654
applianceid          : 143112195179
project              : avwarglab1
zone                 : australia-southeast2-b
newgceinstances      : 0
newgceinstancebackup : 0
```
Some FAQ:


1. How do I tag the VM?    

You need to add a label where the name is *googlebackupplan* and the value is the name of a valid template, in this example it is *snap*
```
googlebackupplan : snap
```
2. What if I want to use my own own label?   

You can do that and then specify it with **-usertag**.   So lets say you add a label to each relevant VM where the label name is *corporatepolicy* and the value is a valid template name, then when you run the command, add **-usertag "corporatepolicy"**

The whole command would look like:
```
New-AGMLibGCEInstanceDiscovery -discoveryfile ./disco.csv -backup -usertag "corporatepolicy"
```
3. How do I learn the names of the templates to use as values for the tags?    

You can either look at Templates in the SLA Architect in AGM or run: **Get-AGMSLT**

4. What if I don't want all instances to be added to AGM   

This function has to add them all to ensure each instance is examined.   If you add them to AGM and then delete them from AGM, they won't be added back in a second run because a label of **unmanaged** will be added to them.

## User Story: Creating GCE Instance from PD Snapshots

In this user story we are going to use Persistent Disk Snapshots to create a new GCE Instance.  This will be done by using the following command:   **New-AGMLibGCPInstance**

This command requires several inputs so first we explore how to get them.

### Demo video

This video will help you understand how to use this command:   https://youtu.be/hh1seRvRZos

### Creating a single GCE Instance from Snapshot

The best way to create the syntax for this command, at least for the first time you run it,  is to simply run the **New-AGMLibGCPInstance** command without any parameters.
This starts what we called *guided mode* which will help you learn all the syntax to run the command.
The guided menus will appear in roughly the same order as the menus appear in the AGM Web GUI.
The end result is you will get several choices:

1. Run the command
1. Print out a simple command to run later.   Note you may want to edit this command as we explain in the next section.
1. Print out a sample CSV file to use with  **New-AGMLibGCPInstanceMultiMount**

#### Determining which image is used for the mount

The sample command printed by guidedmode has an imageid, an appid and an appname. Consider:
```
-appid       If you specify this, then the most recent image for that app will be mounted.  This is the most exact choice to get the latest image.
-appname     If you specify this, then the most recent image for that app will be mounted provided the appname is unique.   If the appname is not unique, then you will need to switch to appid.
-imageid     If you specify this, then this image will be mounted. You will need to learn this imageid before you run the command.
-imagename   If you specify this, then this image will be mounted. You will need to learn this imagename before you run the command.
```
In general the best choice is **-appid** as it saves you having to work out the imageid or imagename and gives you the most recent image (for the best RPO), 
If constructing a CSV file for multi mount you always need to specify the appname, even if you are using the appid.  This is to ensure we can identify the source app.

#### Manually constructing output

If you want to manually construct the output, or get some variables to tweak the output, consider the following tips:

To learn which Applications are suitable use this command:
```
Get-AGMApplication -filtervalue "apptype=GCPInstance&managed=True" | select id,appname,@{N='appliancename'; E={$_.cluster.name}}
```
You could use the same command to export to CSV, like this:
```
Get-AGMApplication -filtervalue "apptype=GCPInstance&managed=True" | select id,appname | Export-Csv -Path ./applist.csv
Get-Content ./applist.csv
```

To learn which Cloud Credential srcids are available use this command:
```
Get-AGMLibCredentialSrcID
```
Make sure that the credential is on the same appliance that is managing the application.
To learn the image ID or image name, you could use this command:
```
Get-AGMImage -filtervalue "apptype=GCPInstance&jobclass=snapshot" | select appname,id,name,consistencydate,diskpool | ft
```
There are many parameters that need to be supplied:
```
-appid           The application ID of the source GCP Instance you want to mount.  If you use this you don't need to specify an image ID or name.   It will use the latest snapshot of that application.
-imageid         You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image)
-imagename       You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image)
-srcid           Learn this with Get-AGMLibCredentialSrcID.   You need to use the correct srcid that matches the appliance that is protecting the application. 
-serviceaccount  The service account that is being used to request the instance creation.  This is optional.  Otherwise it will use the account from the cloud credential (which is the preferred method)
-projectname     This is the unique Google Project name 
-zone            This is the GCP Zone such as: australia-southeast1-c
-instancename    This is the name of the new instance that will be created.   It needs to be unique in that project
-machinetype     This is the GCP instance machine type such as:  e2-micro
-networktags     Comma separate as many tags as you have, for instance:   -networktags "http-server,https-server"   
-labels          Labels are key value pairs.   Separate key and value with colons and each label with commas.   For example:   -labels "pet:cat,drink:milk"
-retainlabel     Specify true and then any labels in the selected image will be retained in the new GCE instance. Partial label retention is not supported.
-nic0network     The network name in URL format for nic0
-nic0subnet      The subnet name in URL format for nic0
-nic0externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic0 is 'none'
-nic0internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic0 will be auto assigned.   
-poweronvm       By default the new GCE Instance will be powered on.   If you want it to be created but left powered off, then specify: -poweronvm false
                 There is no need to specify: -poweronvm true 
```
Optionally you can request a second NIC with these parameters:
```
-nic1network     The network name in URL format for nic1
-nic1subnet      The subnet name in URL format for nic1
-nic1externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic1 is 'none'
-nic1internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic1 will be auto assigned.  
```
Optionally you can also change the disk type of the disks in the new GCP VM:
```
-disktype        Has to be one of:   pd-balanced, pd-extreme, pd-ssd, pd-standard   All disks in the instance will use this disk type
```
You can specify any labels you want to supply for this new GCE VM with -label, for instance:

 **-label "pet:cat,drink:milk"**

However if you add **-retainlabel true** then any labels that were used the GCE Instance when the snapshot was created will be applied to the new VM.
Lets imagine the original VM had a label:

**bird:parrot** 

and we specify the following:   

**-retainlabel true -label "pet:cat,drink:milk"**  

then the new VM will have all three labels (the two new ones and the retained one from the original VM).

This brings us to a command like this one:
```
New-AGMLibGCPInstance -imageid 56410933 -srcid 1234 -zone australia-southeast1-c -projectname myproject -instancename avtest21 -machinetype e2-micro -networktags "http-server,https-server" -labels "dog:cat,sheep:cow" -nic0network "https://www.googleapis.com/compute/v1/projects/projectname/global/networks/default" -nic0subnet "https://www.googleapis.com/compute/v1/projects/projectname/regions/australia-southeast1/subnetworks/default" -nic0externalip auto -nic0internalip "10.152.0.200" -poweronvm false -retainlabel true
```


## User Story: GCE Disaster Recovery using GCE Instance PD Snapshots

### GCE to GCE configuration

The expected configuration in this scenario is that the end-user wants to recover workloads from one GCP zone into another one:

| Production Site  | DR Site |
| ------------- | ------------- |
| GCP Zone | GCP Zone |

The goal is to offer a simplified way to manage failover or failback where:
* The backup mechanism is persistent disk snapshots
* The images are created by a Backup Appliance in an alternate zone
* DR occurs by issuing commands to the DR Appliance to create new GCE Instances in the DR zone.

### Demo video

This video will help you understand how to use this command:   

https://youtu.be/hh1seRvRZos

Note this is the same as the video linked in the previous section.

### GCE to GCE CSV file

In the previous section we explored using the **New-AGMLibGCPInstance** command to create a new GCP VM.  

What we can do is store the parameters needed to run that command in a CSV file.  
We can generate the CSV file by running **New-AGMLibGCPInstance** in guided mode.
We then run the **New-AGMLibGCPInstanceMultiMount** command specifying the CSV file.

Here is an example of the CSV file:
```
appid,srcid,projectname,zone,instancename,machinetype,serviceaccount,networktags,labels,nic0network,nic0subnet,nic0externalip,nic0internalip,nic1network,nic1subnet,nic1externalip,nic1internalip,disktype,poweronvm,retainlabel
35590,28417,prodproject1,australia-southeast1-c,tinym,e2-micro,,"http-server,https-server","dog:cat,sheep:cow",https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/default,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/default,,, ,,,,pd-balanced,TRUE,TRUE
51919,28417,prodproject1,australia-southeast1-c,mysqlsourcem,e2-medium,,,,https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/default,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/default,auto,,https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/actifioanz,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/australia,auto,10.186.0.200,,,,
36104,28417,prodproject1,australia-southeast1-c,mysqltargetm,e2-medium,,,,https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/default,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/default,,10.152.0.200,,,,,pd-ssd,TRUE,TRUE
```
The main thing is the headers in the CSV file needs to be exactly as shown, as they are the parameters we pass to the command (although the field order is not important).
We can then run a command like this specifying our CSV file:
```
New-AGMLibGCPInstanceMultiMount -instancelist recoverylist.csv
```
This will load the contents of the file recoverylist.csv and use it to run multiple **New-AGMLibGCPInstance** jobs.  They will run in parallel but be started serially.
 
If you specify both appid and appname, then the appname column will be ignored.  However having appname is mandatory as it gives you the name of the source application.

What is not supported right now:

1.  Specifying more than one internal IP per subnet.
1.  Specifying different disk types per disk

#### Cleaning up after a multi-mount run

After the multi-mount has finished you may have a large number of GCE Instances to clean up or retain.
One simple strategy is to run this command:
```
Remove-AGMLibMount -gceinstanceforget
```
This will remove the mounted info from AGM side, but leave the instances in place on Google Side.
Then on the Google Console side, keep or delete them as you wish.

#### Monitoring the jobs created by a multi mount by creating an object

When you run a multimount, by default all jobs will run before any output is printed.   What we output is a nicely formatted object listing each line in the CSV, the app details, the command that was run and the results.  

The best way to manage this is to load this output into your own object, so do something like this:
```
$newrun = New-AGMLibGCPInstanceMultiMount -instancelist april12test1.csv
```
Then display the output like this:
```
PS > $newrun
```
You can then find all the jobs that didn't start like this:
```
PS > $newrun | where-object {$_.result -ne "started"}
```
Once you understand the error you can manually learn the command like this, so you can edit it and run it manually:
```
($newrun | where-object {$_.result -ne "started"}).command
```


#### Monitoring the jobs created by a multi mount by realtime output to the screen
If you just want to see the status output as each job is run, then add **-textoutput**

The output will look like this:
```
PS >  New-AGMLibGCEConversionMulti -instancelist april12test1.csv -textoutput

The following command encountered this error:       Instance Name already in use
New-AGMLibGCEConversion -projectname project1 -machinetype n1-standard-2 -instancename "apr12test1centos1" -nic0network "https://www.googleapis.com/compute/v1/projects/project1/global/networks/actifioanz" -nic0subnet "https://www.googleapis.com/compute/v1/projects/project1/regions/australia-southeast1/subnetworks/australia" -region "australia-southeast1" -zone "australia-southeast1-a" -srcid "391360" -appname "Centos1" -serviceaccount "systemstaterecovery@project1.iam.gserviceaccount.com" -preferedsource onvault

The following command started this job:  Job_0867154Optional[Job_0867154] to mount londonsky.c.project1.internal_Image_0499948 started
New-AGMLibGCEConversion -projectname project1 -machinetype n1-standard-2 -instancename "apr12test1centos3" -nic0network "https://www.googleapis.com/compute/v1/projects/project1/global/networks/actifioanz" -nic0subnet "https://www.googleapis.com/compute/v1/projects/project1/regions/australia-southeast1/subnetworks/australia" -region "australia-southeast1" -zone "australia-southeast1-a" -srcid "391360" -appname "Centos3" -serviceaccount "systemstaterecovery@project1.iam.gserviceaccount.com" -preferedsource onvault

PS >
```

## User Story: Creating GCE Instance from VMware Snapshots

In this user story we are going to use VMware VM snapshots (or system state backups) to create a new GCE Instance.  This will be done by using the **New-AGMLibGCEConversion** command.

This command requires several inputs so first we explore how to get them.

### Creating a single GCE Instance from VMware/System State Backup

The best way to create the syntax for this command, at least for the first time you run it,  is to simply run the **New-AGMLibGCEConversion** command without any parameters.
This starts what we called *guided mode* which will help you learn all the syntax to run the command.
The guided menus will ask questions in roughly the same order as the menus appear in the AGM Web GUI.
The end result is you will get several choices:

1. Run the command there and then
1. Print out a simple command to run later.   Note you may want to edit this command as we explain in a moment.
1. Print out a sample CSV file to use with  **New-AGMLibGCEConversionMulti**

#### Determining which image is used for the mount

The sample command printed by guidedmode has an imageid, an appid and an appname. Consider:
```
-appid       If you specify this, then the most recent image for that app will be mounted.  This is the most exact choice to get the latest image.
-appname     If you specify this, then the most recent image for that app will be mounted provided the appname is unique.   If the appname is not unique, then you will need to switch to appid.
-imageid     If you specify this, then this image will be mounted. You will need to learn this imageid before you run the command.
-imagename   If you specify this, then this image will be mounted. You will need to learn this imagename before you run the command.
```
In general the best choice is **-appid** as it saves you having to work out the imageid or name and gives you the most recent image (for the latest RPO).
If constructing a CSV file for multi mount you always need to include the **appname**, even if you are using the **appid**.  This is to ensure we can identify the source app.

#### Manually constructing output

If you want to manually construct the output, or get some variables to tweak the output consider the following tips:

To learn which Cloud Credential srcids are available use the following command.  Note that this is appliance specific, so when you specify a srcid you are specifing a service account that is stored on a specific appliance.  This means if you want to split the workload across multiple appliances, then you can do this by using the relevant srcid of each appliance (although this also need the relevant applications to be imported into the relative appliances when using OnVault backups).
```
Get-AGMLibCredentialSrcID
```
To learn the AppIDs use this command (note the ApplianceName is where the images were created, in other words the source appliance, not the one running the mount):
```
Get-AGMApplication -filtervalue "apptype=SystemState&apptype=VMBackup" | select id,appname,@{N='appliancename'; E={$_.cluster.name}} | sort-object appname
```
To learn the image ID or image name, you could use this command (change jobclass to snapshot or StreamSnap if needed):
```
Get-AGMImage -filtervalue "apptype=SystemState&apptype=VMBackup&jobclass=OnVault" | select appname,id,name,consistencydate,@{N='diskpoolname'; E={$_.diskpool.name}} | sort-object appname,consistencydate | format-table
```

There are many parameters that may need to be supplied:
```
-appid           The application ID of the source VMWare VM or System State you want to mount.  If you use this you don't need to specify an image ID or imagename.   It will use the latest image of that application.
-appname         The application name of the source VMWare VM or System State you want to mount.  This needs to be unique.  If you use this you don't need to specify an image ID or imagename.   It will use the latest image of that application.
-imageid         You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image).  To avoid using this, you can specify -appid or -appname instead
-imagename       You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image).  To avoid using this, you can specify -appid or -appname instead
-srcid           Learn this with Get-AGMLibCredentialSrcID.  You need to use the correct srcid that matches the appliance that is going to run the mount.
-serviceaccount  The service account.
-projectname     This is the unique Google Project name where the new instance will be created.
-sharedvpcprojectid  If the instance is being created in a service project, what is the ID the project that is sharing the VPC (optional)
-nodegroup       If creating an instance into a sole tenant node group, this is the name of the node group (optional)
-region          This is the GCP Region such as:   australia-southeast1
-zone            This is the GCP Zone such as: australia-southeast1-c
-instancename    This is the name of the new instance that will be created.   It needs to be unique in that project
-machinetype     This is the GCP instance machine type such as:  e2-micro
-networktags     Comma separate as many tags as you have, for instance:   -networktags "http-server,https-server"   
-labels          Labels are key value pairs.   Separate key and value with colons and each label with commas.   For example:   -labels "pet:cat,food:fish"
-nic0network     The network name in URL format for nic0
-nic0subnet      The subnet name in URL format for nic0
-nic0externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic0 is 'none'
-nic0internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic0 will be auto assigned.   
-poweroffvm      By default the new GCE Instance will be left powered on after creation.   If you want it to be created but then powered off, then specify this flag.
-migratevm       By default the new GCE Instance will be dependent on the Actifio Appliance.  To migrate all data onto GCE PD, then specify this flag.
-preferedsource  Optional,  used if we want to force selection of images from a particular storage pool, either snapshot, streamsnap or onvault  (use lower case)
```
Optionally you can request a second NIC using nic1:
```
-nic1network     The network name in URL format for nic1
-nic1subnet      The subnet name in URL format for nic1
-nic1externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic1 is 'none'
-nic1internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic1 will be auto assigned.   
```
Optionally you can specify that all disks be a different type:
```
-disktype        Has to be one  of pd-balanced, pd-extreme, pd-ssd, pd-standard   All disks in the instance will use this disk type
```
This bring us to command like this one:
```
New-AGMLibGCEConversion -imageid 56410933 -srcid 1234 -region australia-southeast1 -zone australia-southeast1-c -projectname myproject -instancename avtest21 -machinetype e2-micro -networktags "http-server,https-server" -labels "dog:cat,sheep:cow" -nic0network "https://www.googleapis.com/compute/v1/projects/projectname/global/networks/default" -nic0subnet "https://www.googleapis.com/compute/v1/projects/projectname/regions/australia-southeast1/subnetworks/default" -nic0externalip auto -nic0internalip "10.152.0.200" -poweroffvm 
```

What is not supported right now:
1)  Specifying more than one internal IP per subnet.
2)  Specifying different disk types per disk

If you get timeouts, then increase the timeout value with **-timeout 60** when running connect-agm

## User Story: GCE Disaster Recovery using VMware VM Snapshots

### VMware to GCE configuration

The expected configuration in this scenario is that the end-user will be looking to recover workloads from VMware into a GCP Zone

| Production Site  | DR Site |
| ------------- | ------------- |
| VMware | GCP Zone |

The goal is to offer a simplified way to manage failover from Production to DR where:
* The backup mechanism is to use VMware snapshots or System State backup
* These images are created by an on-premises Backup Appliance and then replicated into cloud either in an OnVault pool or via StreamSnap.
* DR occurs by issuing commands to the DR Appliance to create new GCE Instances (most likely after importing the OnVault images)
* You may need to first run an OnVault import using this method: https://github.com/Actifio/AGMPowerLib/tree/0.0.0.43#importing-onvault-images

The best way to create the syntax for this command, at least for the first time you run it,  simply run the **New-AGMLibGCEConversion** command without any parameters.
This starts what we called *guided mode* which will help you create the command.
The guided menus will appear in roughly the same order as the menus appear in the AGM Web GUI.
The end result is you wil get two choices:

1. Print out a simple command
1. Print out a sample CSV file to use with  **New-AGMLibGCEConversionMulti**

If you want to manually construct the output, or get some variables to tweak the output consider the following tips:


### VMware to GCE CSV file

We can take the **New-AGMLibGCEConversion** command to create a new GCP VM and store the parameters needed to run that command in a CSV file. 

If the applications are not yet imported you can use the appname  field provided the VMnames are unique.
Here is an example of the CSV file:
```
srcid,appid,appname,projectname,sharedvpcprojectid,region,zone,instancename,machinetype,serviceaccount,nodegroup,networktags,poweroffvm,migratevm,labels,preferedsource,disktype,nic0network,nic0subnet,nic0externalip,nic0internalip,nic1network,nic1subnet,nic1externalip,nic1internalip
391360,296433,"Centos2","project1","hostproject1","europe-west2","europe-west2-a","newvm1","n1-standard-2","systemstaterecovery@project1.iam.gserviceaccount.com","nodegroup1","https-server",False,True,status:failover,onvault,pd-standard,https://www.googleapis.com/compute/v1/projects/project1/global/networks/actifioanz,https://www.googleapis.com/compute/v1/projects/project1/regions/europe-west2/subnetworks/default,auto,,https://www.googleapis.com/compute/v1/projects/project1/global/networks/default,https://www.googleapis.com/compute/v1/projects/project1/regions/europe-west2/subnetworks/default,,  
       
```
The main thing is the headers in the CSV file needs to be exactly as shown as they are the parameters we pass to the command (although the order is not important).
We can then run a command like this specifying our CSV file:
```
New-AGMLibGCEConversionMulti -instancelist recoverylist.csv 
```
This will load the contents of the file **recoverylist.csv** and use it to start multiple **New-AGMLibGCEConversion** jobs.   The jobs will run in parallel (up to the slot limit), but will be started in series.
   
What is not supported right now:

1.  Specifying more than one internal IP per subnet.
1.  Specifying different disk types per disk
1.  More than two NICS per instance

#### Monitoring the jobs created by a multi mount by creating an object

When you run a multimount, by default all jobs will run before any output is printed.   What we output is a nicely formatted object listing each line in the CSV, the app details, the command that was run and the results.  

The best way to manage this is to load this output into your own object, so do something like this:
```
$newrun = New-AGMLibGCEConversionMulti -instancelist april12test1.csv
```
Then display the output like this:
```
PS > $newrun

appname : Centos3
appid   :
result  : started
message : Job_0866903Optional[Job_0866903] to mount londonsky.c.project1.internal_Image_0499948 started
command : New-AGMLibGCEConversion -projectname project1 -machinetype n1-standard-2 -instancename "apr12test1centos3" -nic0network "https://www.googleapis.com/compute/v1/projects/project1/global/networks/actifioanz" -nic0subnet "https://www.googleapis.com/compute/v1/projects/project1/regions/australia-southeast1/subnetworks/australia" -region "australia-southeast1" -zone "australia-southeast1-a" -srcid
          "391360" -appname "Centos3" -serviceaccount "systemstaterecovery@project1.iam.gserviceaccount.com" -preferedsource onvault

appname : centos2
appid   :
result  : failed
message : Failed to resolve centos2 to a unique valid VMBackup or System State app.  Use Get-AGMLibApplicationID and try again specifying -appid
command : New-AGMLibGCEConversion -projectname project1 -machinetype n1-standard-2 -instancename "apr12test1centos2" -nic0network "https://www.googleapis.com/compute/v1/projects/project1/global/networks/actifioanz" -nic0subnet "https://www.googleapis.com/compute/v1/projects/project1/regions/australia-southeast1/subnetworks/australia" -region "australia-southeast1" -zone "australia-southeast1-a" -srcid
          "391360" -appname "centos2" -serviceaccount "systemstaterecovery@project1.iam.gserviceaccount.com" -preferedsource onvault
```
You can then find all the jobs that didn't start like this:
```
PS > $newrun | where-object {$_.result -ne "started"}

appname : centos2
appid   :
result  : failed
message : Failed to resolve centos2 to a unique valid VMBackup or System State app.  Use Get-AGMLibApplicationID and try again specifying -appid
command : New-AGMLibGCEConversion -projectname project1 -machinetype n1-standard-2 -instancename "apr12test1centos2" -nic0network "https://www.googleapis.com/compute/v1/projects/project1/global/networks/actifioanz" -nic0subnet "https://www.googleapis.com/compute/v1/projects/project1/regions/australia-southeast1/subnetworks/australia" -region "australia-southeast1" -zone "australia-southeast1-a" -srcid
          "391360" -appname "centos2" -serviceaccount "systemstaterecovery@project1.iam.gserviceaccount.com" -preferedsource onvault
```
Once you understand the error you can manually learn the command like this, so you can edit it and run it manually:
```
($newrun | where-object {$_.result -ne "started"}).command
```


#### Monitoring the jobs created by a multi mount by creating an object
If you want to just see the output as each job is run, then add **-textoutput**

The output will look like this:
```
PS >  New-AGMLibGCEConversionMulti -instancelist april12test1.csv -textoutput

The following command encountered this error:       Instance Name already in use
New-AGMLibGCEConversion -projectname project1 -machinetype n1-standard-2 -instancename "apr12test1centos1" -nic0network "https://www.googleapis.com/compute/v1/projects/project1/global/networks/actifioanz" -nic0subnet "https://www.googleapis.com/compute/v1/projects/project1/regions/australia-southeast1/subnetworks/australia" -region "australia-southeast1" -zone "australia-southeast1-a" -srcid "391360" -appname "Centos1" -serviceaccount "systemstaterecovery@project1.iam.gserviceaccount.com" -preferedsource onvault

The following command started this job:  Job_0867154Optional[Job_0867154] to mount londonsky.c.project1.internal_Image_0499948 started
New-AGMLibGCEConversion -projectname project1 -machinetype n1-standard-2 -instancename "apr12test1centos3" -nic0network "https://www.googleapis.com/compute/v1/projects/project1/global/networks/actifioanz" -nic0subnet "https://www.googleapis.com/compute/v1/projects/project1/regions/australia-southeast1/subnetworks/australia" -region "australia-southeast1" -zone "australia-southeast1-a" -srcid "391360" -appname "Centos3" -serviceaccount "systemstaterecovery@project1.iam.gserviceaccount.com" -preferedsource onvault

PS >
```

### Managing the mounted GCE Instance 

Once we have created a new GCP Instance from PD snapshot, there is no dependency on Actifio because the disks for the instance are all Persistent Disks rather than shared disks from an Actifio Storage Pool,  but the mount is still shown as an Active Image, which means it needs to be managed.   We can see the Active Images with this command:
```
PS /tmp/agmpowercli> Get-AGMLibActiveImage

imagename        : Image_0021181
apptype          : GCPInstance
appliancename    : project1sky
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
We have two choices on how to handle this image:

1. Unmount and delete. This command deletes the mounted image record on the Actifio GO side and the GCE Instance on the GCP side.

```
PS /tmp/agmpowercli> Remove-AGMMount Image_0021181  -d
PS /tmp/agmpowercli>
```
2. Preserve the image on GCP side. This command deletes the mounted image record on Actifio GO side but leaves the GCE Instance on the GCP side. In the AGM GUI this is called forgetting the image.   You can see the only difference with the choice above is the -p for preserve.
```
PS /tmp/agmpowercli> Remove-AGMMount Image_0021181  -d -p
PS /tmp/agmpowercli>
```
### Appliance Slots and how they are used to control the number of running jobs

The Appliance running your jobs may hit a slot limit, which means that you may see a case where jobs go into queued status, waiting for free slots, rather than starting immediately. 

To resolve this we need to adjust what are called slot values.  Slots are effectively used as a pacing mechanism to control how many jobs can be running on an appliance at any point in time.
Note that while we are using AGMPowerLib commands to do this, you need to ensure your AGMPowerCLI is on version 0.0.0.35 or higher.   You can check your AGMPowerCLI version with this command:
**Get-Command -module AGMPowerCLI**

Firstly learn the ID of the relevant Appliance.  In this case the appliance running our jobs is **project1sky** so we will use applianceid **361153**
```
PS > Get-AGMAppliance | select id,name

id     name
--     ----
361153 project1sky
296357 londonsky.c.project1.internal
```
Now depending on which job type, we modify different slots.
#### Slot limits for mount jobs
We need to learn the current value of the params that relate to **ondemand** slots. This is because a mount job is an ondemand job, meaning each mount job uses one ondemand slot while it is running.  There are three relevant slots:
* **reservedondemandslots** This is the guaranteed number of ondemand jobs that can run at any time.  
* **maxondemandslots** This controls the maximum number of ondemand jobs that can run at any time.  
* **unreservedslots** Unreserved slots are used if all the reserved slots are in use but more jobs wants to run up to the maximum number for that type.

We learn the values with:
```
Get-AGMLibApplianceParameter -applianceid 361153 -param reservedondemandslots
Get-AGMLibApplianceParameter -applianceid 361153 -param maxondemandslots
Get-AGMLibApplianceParameter -applianceid 361153 -param unreservedslots
```
Here is an example:
```
PS > Get-AGMLibApplianceParameter -applianceid 361153 -param reservedondemandslots

reservedondemandslots
---------------------
3
```
We can set the slots to larger values like this:
```
Set-AGMLibApplianceParameter -applianceid 361153 -param reservedondemandslots -value 10
Set-AGMLibApplianceParameter -applianceid 361153 -param maxondemandslots -value 15
Set-AGMLibApplianceParameter -applianceid 361153 -param unreservedslots -value 15
```
Here is an example:
```
PS > Set-AGMLibApplianceParameter -applianceid 361153 -param reservedondemandslots -value 10

reservedondemandslots changed from 3 to 10
```
#### Slot limits for OnVault jobs
We need to learn the current value of the params that relate to **onvault** slots.  Note this is listed as **vault**
* **reservedvaultslots** This is the guaranteed number of OnVault jobs that can run at any time.  
* **maxvaultslots** This controls the maximum number of OnVault jobs that can run at any time.  
* **unreservedslots** Unreserved slots are used if all the reserved slots are in use but more jobs wants to run up to the maximum number for that type.

We learn the values with:
```
Get-AGMLibApplianceParameter -applianceid 361153 -param reservedvaultslots
Get-AGMLibApplianceParameter -applianceid 361153 -param maxvaultslots
Get-AGMLibApplianceParameter -applianceid 361153 -param unreservedslots
```
Set can the slots to larger values like this:
```
Set-AGMLibApplianceParameter -applianceid 361153 -param reservedvaultslots -value 10
Set-AGMLibApplianceParameter -applianceid 361153 -param maxvaultslots -value 15
Set-AGMLibApplianceParameter -applianceid 361153 -param unreservedslots -value 15
```
#### Slot limits for snapshot jobs
We need to learn the current value of the params that relate to **snapshot** slots.
* **reservedsnapslots** This is the guaranteed number of snapshot jobs that can run at any time.  
* **maxsnapslots** This controls the maximum number of snapshot jobs that can run at any time.  
* **unreservedslots** Unreserved slots are used if all the reserved slots are in use but more jobs wants to run up to the maximum number for that type.

We learn the values with:
```
Get-AGMLibApplianceParameter -applianceid 361153 -param reservedsnapslots
Get-AGMLibApplianceParameter -applianceid 361153 -param maxsnapslots
Get-AGMLibApplianceParameter -applianceid 361153 -param unreservedslots
```
We set the slots to larger values like this:
```
Set-AGMLibApplianceParameter -applianceid 361153 -param reservedsnapslots -value 10
Set-AGMLibApplianceParameter -applianceid 361153 -param maxsnapslots -value 15
Set-AGMLibApplianceParameter -applianceid 361153 -param unreservedslots -value 15
```
## User Story: Importing and Exporting AGM Policy Templates

In this user story we are going to export our Policy Templates (also called Service Level Templates or SLTs) from AGM in case we want to import them into a different AGM.

First we login to the source AGM and validate our SLTs.

```
PS /Users/avw> Connect-AGM 10.152.0.5 admin -passwordfile userpass.key -i
Login Successful!
PS /Users/avw> Get-AGMSLT | select id,name

id    name
--    ----
25606 FSSnaps_RW_OV
17796 FSSnaps
6523  Snap2OV
6392  PDSnaps
```
We now export all the SLTs to a file called export.json.  If we only want to export specific SLTs, then don't specify **-all** and you will get a help menu.
```
PS /Users/avw> Export-AGMLibSLT -all -filename export.json
```
We now login to our target AGM:
```
PS /Users/avw> connect-agm 10.194.0.3 admin -passwordfile userpass.key -i
Login Successful!
```
We validate there are no Templates.   Currently this function expects there to be no templates in the target.  However if there are, as long as there are no name clashes, the import will still succeed.  In this example there are no templates in the target.
```
PS /Users/avw> Get-AGMSLT

count items
----- -----
    0 {}

PS /Users/avw>
```
We now import the Templates and then validate we now have four imported SLTs:
```
PS /Users/avw> Import-AGMLibSLT -filename export.json

count items
----- -----
    4 {@{@type=sltRest; id=21067; href=https://10.194.0.3/actifio/slt/21067; name=FSSnaps_RW_OV; override=true; policy_href=https://10.194.0.3/actifio/slt/21067/policy}, @{@type=sltRest; id=21070; href=https://10.194.0.3/acti…

PS /Users/avw> Get-AGMSLT | select id,name

id    name
--    ----
21081 PDSnaps
21072 Snap2OV
21070 FSSnaps
21067 FSSnaps_RW_OV

PS /Users/avw>
```
Our import is now complete.

## Contributing

Have a patch that will benefit this project? Awesome! Follow these steps to have
it accepted.

1.  Please sign our [Contributor License Agreement](CONTRIB.md).
1.  Fork this Git repository and make your changes.
1.  Create a Pull Request.
1.  Incorporate review feedback to your changes.
1.  Accepted!

## License

All files in this repository are under the
[Apache License, Version 2.0](LICENSE) unless noted otherwise.

