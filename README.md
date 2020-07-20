# AGMPowerLib
A Library of PowerShell Scripts to interact with AGM




## SQL Test and Dev Image usage

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

## SQL Test and Dev Image usage with point in time recovery

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

However the eligible list is not easy to read, so lets exand it and put it into a table.  This is much easier to read:

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
