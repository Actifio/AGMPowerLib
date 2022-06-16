# Copyright 2022 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


Function New-AGMLibMSSQLMulti ([string]$sourcefile,[string]$runfile,[switch]$textoutput,[switch]$runmount,[switch]$runmigration,[switch]$startmigration,[switch]$finalizemigration,[switch]$checkimagestate) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of SQL DBs or Instances to create many new Microsoft SQLServer Databases

    .EXAMPLE
    New-AGMLibMSSQLMulti -sourcefile recoverylist.csv  -runfile rundate22052022.csv -checkimagestate

    DBs to be recovered will be source from recoverylist.csv and mounts tracked in rundate22052022.  We use -checkimagestate to check the current progress of each image.
    The id field is used to track the mounted image, previousimagestate shows what state the last command was attenmpting to achieve, while currentimagestate shows the current state of that image.

    .EXAMPLE
    New-AGMLibMSSQLMulti -sourcefile recoverylist.csv  -runfile rundate22052022.csv -runmount

    This will run multiple New-AGMLibMSSQLMount jobs.  If run twice, any collisions with existing mounts will not run. 
    This means if a mount fails, if you resolve the cause of the issue you can just run the same command again with interfering with existing mounts.

    .EXAMPLE
    New-AGMLibMSSQLMulti -sourcefile recoverylist.csv -runfile rundate22052022.csv -startmigration

    This will start migrate jobs for any SQL Db where the migrate field is set to true.
    
    .EXAMPLE
    New-AGMLibMSSQLMulti -sourcefile recoverylist.csv -runfile rundate22052022.csv -runmigration

    This will run a migration job for each DB that has a started migration
    
    .EXAMPLE
    New-AGMLibMSSQLMulti -sourcefile recoverylist.csv -runfile rundate22052022.csv -finalizemigration

    This will finalize the migration for each DB that has a started migration



    .DESCRIPTION
    This routine needs a well formatted CSV file. This file can be created by running New-AGMLibMSSQLMount in guided mode (by starting it without specifying any options.
    Note the column order is not important.    
    Here is an example of such a file:

    appid,appname,imagename,imageid,mountapplianceid,targethostid,targethostname,sqlinstance,recoverypoint,recoverymodel,overwrite,label,dbname,consistencygroupname,dbnamelist,dbrenamelist,dbnameprefix,dbnamesuffix,recoverdb,userlogins,username,password,base64password,mountmode,mapdiskstoallesxhosts,mountpointperimage,sltid,slpid,discovery,perfoption,migrate,copythreadcount,frequency,dontrenamedatabasefiles,volumes,files,restorelist
    ,WINDOWS\SQLEXPRESS,,,143112195179,,win-target,WIN-TARGET\SQLEXPRESS,,Same as source,no,sqlinst1,,avcg1,,"model,model1;CRM,crm1",,,TRUE,FALSE,,,,,,,,,,,yes,4,1,,,,

    If you specify both appname and appid then appid will be used.  The appname is mandatory so you know the name of the source DB.
    In general you do not want to use the imagename or imageid column (so blank them out of even remove them) because normally we just want the latest image, rather than a specific one.
    For discovery to be requested, add t or true (or any text) to the discovery column.  If any text appears at all (including the word false), then discovery will be requested.

    The following columns are used for migration:
    migrate,copythreadcount,frequency,dontrenamedatabasefiles,volumes,files,restorelist
     
    migrate (switch) - Left blank:  no migration.  Set (any character):  image will be migrated
    copythreadcount (integer) -  Left blank:  4 threads else set as number of threads   
    frequency (integer) - Left blank: 24 hours  else set a number of hours
    dontrenamedatabasefiles (switch): Left blank: files will be renamed to match the new database name else enter any value and files will NOT be renamed
    volumes (switch) - Left blank, migration expects same drive letters.  Else enter true and usethe restorelist must contain the source drive letter and the target drive letter.
    files (switch) - Left blank: migration expects same file names. Else enter true and use the restorelist must contain the file name, the source location and the targetlocation. 
    restorelist -  files format is: filename1,source1,target1;filename2,source2,target2     volume format is: D:\,K:\;E:\,M:\


    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    $sessiontest = Get-AGMVersion
    if ($sessiontest.errormessage)
    {
        Get-AGMErrorMessage -messagetoprint "AGM session has expired. Please login again using Connect-AGM"
        return
    }
    
    if (!($sourcefile))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a source csv file correctly formatted as per the help for this function using: -sourcefile xxxx.csv"
        return;
    }
    if (!($runfile))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a file name (the file should not exist) to store run data created by this function using: -runfile xxxx.csv"
        return;
    }
    if (-not (Test-Path $sourcefile ))
    {
        Get-AGMErrorMessage -messagetoprint "The sourcefile specified $sourcefile could not be found"
        return;
    }

    if (-not (Test-Path $runfile ))
    {
        Copy-Item $sourcefile -Destination $runfile
        $recoverylist = Import-Csv -Path $runfile
        $recoverylist | Add-Member -MemberType NoteProperty -Name previousimagestate -value ""
        $recoverylist | Add-Member -MemberType NoteProperty -Name mountedimageid -value ""
    }
    else
    {
        $recoverylist = Import-Csv -Path $runfile
    }


    # first we quality check the CSV
    if ($recoverylist.mountapplianceid -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: mountapplianceid" ;return }
    if (($recoverylist.appname -eq $null) -and ($recoverylist.appid -eq $null))  {  Get-AGMErrorMessage -messagetoprint "Could not find either appid or appname columns" ; return }


    write-host ""
    if (!($textoutput))
    {
        $printarray = @()
    }


    # dry run for srcid and appname
    $row =1
    foreach ($app in $recoverylist)
    {
        if ($app.mountapplianceid -eq "") { write-host  "The following mandatory value is missing: mountapplianceid in row $row" ; return }
        $row += 1
    }
    $row =1
    foreach ($app in $recoverylist)
    {
        if ($app.appname -eq "")  { write-host "The following mandatory value is missing: appname row $row" ; return}
        $row += 1
    }


    if ($checkimagestate)
    {
        # first grab all the mounts
        $activeimagegrab = Get-AGMImage -filtervalue "jobclass=5&jobclass=15&jobclass=19&jobclass=32&jobclass=48&jobclass=59&jobclass=56&jobclass=52&characteristic=1&characteristic=2"
        if ($activeimagegrab.id)
        {
            $mountarray = @()
            # not look throught the mounts for ones that can migrate or are migrating and make an array
            Foreach ($id in $activeimagegrab)
            { 
                $imagestate = ""
                $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.cluster.name
                $id | Add-Member -NotePropertyName hostname -NotePropertyValue $id.host.hostname
                $id | Add-Member -NotePropertyName appid -NotePropertyValue $id.application.id
                $id | Add-Member -NotePropertyName targethostname -NotePropertyValue $id.mountedhost.hostname
                $id | Add-Member -NotePropertyName targethostid -NotePropertyValue $id.mountedhost.id
                $id | Add-Member -NotePropertyName childappname -NotePropertyValue $id.childapp.appname
                
                if ( $id.flags_text -contains "JOBFLAGS_FINALIZE_ELIGIBLE")
                {
                    $imagestate = "FinalizeEligible"
                }
                elseif ( $id.flags_text -contains "JOBFLAGS_MIGRATING")
                {
                    $imagestate = "MigrateStarted"
                }
                elseif ( $id.flags_text -contains "MIGRATE_ELIGIBLE")
                {
                    $imagestate = "MigrateElibible"
                }
                elseif ($id.characteristic -eq "Mount")
                {
                    $imagestate = "Mounted"
                }
                else 
                {
                    $imagestate = "Unmounted"
                }
                if ($imagestate)
                {
                    $mountarray += [pscustomobject]@{
                        id = $id.id
                        apptype = $id.apptype
                        appliancename = $id.appliancename
                        hostname = $id.hostname
                        appname = $id.appname
                        targethostname = $id.targethostname
                        targethostid = $id.targethostid
                        childappname = $id.childappname
                        label = $id.label
                        imagestate = $imagestate
                    }
                }
            }
        }
        # now lok through the images we want to mount and report on them
        $printarray = @()
        foreach ($app in $recoverylist)
        {
            $childappname = ""
            $childapptype = ""

            # if we have a CG name, then look here
            if (($app.consistencygroupname) -and ($app.targethostname)) 
            {
                $mountpeek = $mountarray | where-object {($_.childappname -eq $app.consistencygroupname) -and ($_.targethostname -eq $app.targethostname) -and ($_.label -eq $app.label)}
                $childappname = $app.consistencygroupname
                $childapptype = "ConsistencyGroup"
            }
            if (($app.consistencygroupname) -and ($app.targethostid)) 
            {
                $mountpeek = $mountarray | where-object {($_.childappname -eq $app.consistencygroupname) -and ($_.targethostid -eq $app.targethostid) -and ($_.label -eq $app.label)}
                $childappname = $app.consistencygroupname
                $childapptype = "ConsistencyGroup"
            }
            # if we have a rename list, but only one DB, then look her
            if ($app.dbrenamelist)
            {
                if ($app.dbrenamelist.Split(";").count -eq 1)
                {
                    $childappname = $app.dbrenamelist.Split(",") | Select-object -skip 1
                    $childapptype = "SqlServerWriter"
                    if ($app.targethostname)
                    {
                        $mountpeek = $mountarray | where-object {($_.childappname -eq $childappname) -and ($_.targethostname -eq $app.targethostname) -and ($_.label -eq $app.label)}
                    }
                    if ($app.$targethostid)
                    {
                        $mountpeek = $mountarray | where-object {($_.childappname -eq $childappname) -and ($_.targethostid -eq $app.targethostid ) -and ($_.label -eq $app.label)}
                    }
                    
                }
                else {
                    $childappname = $app.consistencygroupname
                    $childapptype = "ConsistencyGroup"
                }
            }
            # if we have a name list with a single name
            if ($app.dbnamelist)
            {
                if (($app.dbnamelist.Split(",").count -eq 1) -and (!($app.dbname)))
                {
                    $childappname = $app.dbnamelist
                    $childapptype = "SqlServerWriter"
                    if ($app.targethostname)
                    {
                        $mountpeek = $mountarray | where-object {($_.childappname -eq $childappname) -and ($_.targethostname -eq $app.targethostname) -and ($_.label -eq $app.label)}
                    }
                    if ($app.$targethostid)
                    {
                        $mountpeek = $mountarray | where-object {($_.childappname -eq $childappname) -and ($_.targethostid -eq $app.targethostid ) -and ($_.label -eq $app.label)}
                    }
                }
                else
                {
                    $childappname = $app.consistencygroupname
                    $childapptype = "ConsistencyGroup"
                }
            }
            # if we have a single DB mount 
            if (($app.dbname) -and ($app.targethostname))
            {
                $mountpeek = $mountarray | where-object {($_.childappname -eq $app.dbname) -and ($_.targethostname -eq $app.targethostname) -and ($_.label -eq $app.label)}
                $childappname = $app.dbname
                $childapptype = "SqlServerWriter"
            }
            if (($app.dbname) -and ($app.$targethostid))
            {
                $mountpeek = $mountarray | where-object {($_.childappname -eq $app.dbname) -and ($_.targethostid -eq $app.targethostid ) -and ($_.label -eq $app.label)}
                $childappname = $app.dbname
                $childapptype = "SqlServerWriter"
            }
            if ($mountpeek.id)
            {
                $app.mountedimageid = $mountpeek.id
            }
            
            if ($app.mountedimageid)
            {
                $mountdetails = $mountarray | where-object {$_.id -eq $app.mountedimageid}
                if ($mountdetails)
                {
                $printarray += [pscustomobject]@{
                    id = $mountdetails.id
                    appname = $mountdetails.appname
                    targethostname = $mountdetails.targethostname
                    childapptype = $childapptype
                    childappname = $mountdetails.childappname
                    label = $mountdetails.label
                    previousimagestate = $app.previousimagestate
                    currentimagestate = $mountdetails.imagestate}
                }
                else 
                {
                    $printarray += [pscustomobject]@{
                        id = $app.mountedimageid
                        appname = $app.appname
                        targethostname = $app.targethostname
                        childapptype = $childapptype
                        childappname = $childappname
                        label = $app.label
                        previousimagestate = $app.previousimagestate
                        currentimagestate = "ImageNotFound"}
                }
            }
            else
            {
                $printarray += [pscustomobject]@{
                    id = ""
                    appname = $app.appname
                    targethostname = $app.targethostname
                    childapptype = $childapptype
                    childappname = $childappname
                    label = $app.label
                    previousimagestate = $app.previousimagestate
                    currentimagestate = "NoMountedImage"
                }
            }
        }
       $printarray
       $recoverylist | Export-csv -path $runfile
    }

    
    $printarray = @()
    if ($runmount)
    {
        foreach ($app in $recoverylist)
        {
            $mountcommand = 'New-AGMLibMSSQLMount -mountapplianceid ' +$app.mountapplianceid 
            if ($app.appid) { $mountcommand = $mountcommand + ' -appid "' +$app.appid +'"' } 
            if ($app.targethostid) { $mountcommand = $mountcommand + ' -targethostid "' +$app.targethostid +'"' } 
            if ($app.imagename) { $mountcommand = $mountcommand + ' -imagename "' +$app.imagename +'"' } 
            if ($app.imageid) { $mountcommand = $mountcommand + ' -imageid "' +$app.imageid +'"' } 
            if ($app.targethostname) { $mountcommand = $mountcommand + ' -targethostname "' +$app.targethostname +'"' } 
            if ($app.appname) { $mountcommand = $mountcommand + ' -appname "' +$app.appname +'"' } 
            if ($app.sqlinstance) { $mountcommand = $mountcommand + ' -sqlinstance "' +$app.sqlinstance +'"' } 
            if ($app.dbname) { $mountcommand = $mountcommand + ' -dbname "' +$app.dbname +'"' } 
            if ($app.recoverypoint) { $mountcommand = $mountcommand + ' -recoverypoint "' +$app.recoverypoint +'"' } 
            if ($app.recoverymodel) { $mountcommand = $mountcommand + ' -recoverymodel "' +$app.recoverymodel +'"' } 
            if ($app.overwrite) { $mountcommand = $mountcommand + ' -overwrite "' +$app.overwrite +'"' } 
            if ($app.label) { $mountcommand = $mountcommand + ' -label "' +$app.label +'"' } 
            if ($app.consistencygroupname) { $mountcommand = $mountcommand + ' -consistencygroupname "' +$app.consistencygroupname +'"' } 
            if ($app.dbnameprefix) { $mountcommand = $mountcommand + ' -dbnameprefix "' +$app.dbnameprefix +'"' } 
            if ($app.dbrenamelist) { $mountcommand = $mountcommand + ' -dbrenamelist "' +$app.dbrenamelist +'"' } 
            if ($app.dbnamesuffix) { $mountcommand = $mountcommand + ' -labels "' +$app.labels +'"' } 
            if ($app.recoverdb) { $mountcommand = $mountcommand + ' -recoverdb "' +$app.recoverdb +'"' }          
            if ($app.userlogins) { $mountcommand = $mountcommand + ' -userlogins "' +$app.userlogins +'"' } 
            if ($app.username) { $mountcommand = $mountcommand + ' -username "' +$app.username +'"' } 
            if ($app.password) { $mountcommand = $mountcommand + ' -password "' +$app.password +'"' } 
            if ($app.mountmode) { $mountcommand = $mountcommand + ' -mountmode "' +$app.mountmode +'"' } 
            if ($app.mapdiskstoallesxhosts) { $mountcommand = $mountcommand + ' -mapdiskstoallesxhosts "' +$app.mapdiskstoallesxhosts +'"' } 
            if ($app.mountpointperimage) { $mountcommand = $mountcommand + ' -mountpointperimage "' +$app.mountpointperimage +'"' } 
            if ($app.sltid) { $mountcommand = $mountcommand + ' -sltid "' +$app.sltid +'"' } 
            if ($app.slpid) { $mountcommand = $mountcommand + ' -slpid "' +$app.slpid +'"' } 
            if ($app.discovery) { $mountcommand = $mountcommand + ' -discovery ' } 
            if ($app.perfoption) { $mountcommand = $mountcommand + ' -perfoption "' +$app.perfoption +'"' } 

            # if there is a mountedimageid set, it is now invalid, clear it:
            $app.mountedimageid = ""

            $runcommand = Invoke-Expression $mountcommand 
            $app.previousimagestate = "MountStarted" 
            if ($runcommand.errormessage)
            { 
                if ($textoutput)
                {
                    write-host "The following command encountered this error: " $runcommand.errormessage 
                    $mountcommand
                    write-host ""
                }
                else {
                    $printarray += [pscustomobject]@{
                        appname = $app.appname
                        appid = $app.appid
                        result = "failed"
                        message = $runcommand.errormessage.Trim()
                        command =  $mountcommand }
                        
                        $app.previousimagestate = "MountFailed: $($runcommand.err_message.Trim())"
                }
            }
            elseif ($runcommand.err_message)
            { 
                if ($textoutput)
                {
                    write-host "The following command encountered this error: " $runcommand.err_message 
                    $mountcommand
                    write-host ""
                }
                else {
                    $printarray += [pscustomobject]@{
                        appname = $app.appname
                        appid = $app.appid
                        result = "failed"
                        message = $runcommand.err_message.Trim()
                        errorcode = $runcommand.err_code 
                        command =  $mountcommand }
                        $app.previousimagestate = "MountFailed: $($runcommand.err_message.Trim())" 
                }
            }
            else
            {
                if ($textoutput)
                {
                    write-host "The following command started a job"
                    $mountcommand 
                    write-host ""
                }
                else 
                {
                    $printarray += [pscustomobject]@{
                        appname = $app.appname
                        appid = $app.appid
                        result = "started"
                        message = $runcommand.jobstatus 
                        command =  $mountcommand }
                }
            }
        }
        
        if (!($textoutput))
        {
            $printarray
        }
        $recoverylist | Export-csv -path $runfile
    }


    # start the migration!
    if ($startmigration) 
    {
        # we need the mount array in case we dont know the mountimageID
        $activeimagegrab = Get-AGMImage -filtervalue "jobclass=5&jobclass=15&jobclass=19&jobclass=32&jobclass=48&jobclass=59&jobclass=56&jobclass=52&characteristic=1&characteristic=2"
        $mountarray = @()
        # not look throught the mounts for ones that can migrate or are migrating and make an array
        Foreach ($id in $activeimagegrab)
        { 
            $imagestate = ""
            $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.cluster.name
            $id | Add-Member -NotePropertyName hostname -NotePropertyValue $id.host.hostname
            $id | Add-Member -NotePropertyName appid -NotePropertyValue $id.application.id
            $id | Add-Member -NotePropertyName targethostname -NotePropertyValue $id.mountedhost.hostname 
            $id | Add-Member -NotePropertyName targethostid -NotePropertyValue $id.mountedhost.id
            $id | Add-Member -NotePropertyName childappname -NotePropertyValue $id.childapp.appname
            if ( $id.flags_text -contains "JOBFLAGS_FINALIZE_ELIGIBLE")
            {
                $imagestate = "FinalizeEligible"
            }
            elseif ( $id.flags_text -contains "JOBFLAGS_MIGRATING")
            {
                $imagestate = "MigrateStarted"
            }
            elseif ( $id.flags_text -contains "MIGRATE_ELIGIBLE")
            {
                $imagestate = "MigrateElibible"
            }
            elseif ($id.characteristic -eq "Mount")
            {
                $imagestate = "Mounted"
            }
            else 
            {
                $imagestate = "Unmounted"
            }
            if ($imagestate)
            {
                $mountarray += [pscustomobject]@{
                    id = $id.id
                    apptype = $id.apptype
                    appliancename = $id.appliancename
                    hostname = $id.hostname
                    appname = $id.appname
                    targethostname = $id.targethostname
                    targethostid = $id.targethostid
                    childappname = $id.childappname
                    label = $id.label
                    imagestate = $imagestate
                }
            }
        }
        # migration time   [string]$imagename,[string]$imageid,[int]$copythreadcount,[int]$frequency,[switch]$dontrenamedatabasefiles,[switch]$volumes,[switch]$files,[string]$restorelist
        foreach ($app in $recoverylist)
        {
            if ($app.migrate)
            {
                if ($app.mountedimageid -eq "")
                {
                    # if we have a CG name, then look here
                    if (($app.consistencygroupname) -and ($app.targethostname)) 
                    {
                        $mountpeek = $mountarray | where-object {($_.childappname -eq $app.consistencygroupname) -and ($_.targethostname -eq $app.targethostname) -and ($_.label -eq $app.label)}
                    }
                    if (($app.consistencygroupname) -and ($app.targethostid)) 
                    {
                        $mountpeek = $mountarray | where-object {($_.childappname -eq $app.consistencygroupname) -and ($_.targethostid -eq $app.targethostid) -and ($_.label -eq $app.label)}
                    }
                    # if we have a rename list, but only one DB, then look her
                    if ($app.dbrenamelist)
                    {
                        if ($dbrenamelist.Split(";").count -eq 1)
                        {
                            $singledbname = $app.dbrenamelist.Split(",") | Select-object -skip 1
                            if ($app.targethostname)
                            {
                                $mountpeek = $mountarray | where-object {($_.childappname -eq $singledbname) -and ($_.targethostname -eq $app.targethostname) -and ($_.label -eq $app.label)}
                            }
                            if ($app.$targethostid)
                            {
                                $mountpeek = $mountarray | where-object {($_.childappname -eq $singledbname) -and ($_.targethostid -eq $app.targethostid ) -and ($_.label -eq $app.label)}
                            }
                        }
                    }
                    # if we have a name list with a single name
                    if ($app.dbnamelist)
                    {
                        if (($app.dbnamelist.Split(",").count -eq 1) -and (!($app.dbname)))
                        {
                            $singledbname = $app.dbnamelist
                            if ($app.targethostname)
                            {
                                $mountpeek = $mountarray | where-object {($_.childappname -eq $singledbname) -and ($_.targethostname -eq $app.targethostname) -and ($_.label -eq $app.label)}
                            }
                            if ($app.$targethostid)
                            {
                                $mountpeek = $mountarray | where-object {($_.childappname -eq $singledbname) -and ($_.targethostid -eq $app.targethostid ) -and ($_.label -eq $app.label)}
                            }
                        }
                    }
                    # if we have a single DB mount 
                    if (($app.dbname) -and ($app.targethostname))
                    {
                        $mountpeek = $mountarray | where-object {($_.childappname -eq $app.dbname) -and ($_.targethostname -eq $app.targethostname) -and ($_.label -eq $app.label)}
                    }
                    if (($app.dbname) -and ($app.$targethostid))
                    {
                        $mountpeek = $mountarray | where-object {($_.childappname -eq $app.dbname) -and ($_.targethostid -eq $app.targethostid ) -and ($_.label -eq $app.label)}
                    }
                    if ($mountpeek.id)
                    {
                        $app.mountedimageid = $mountpeek.id
                    }
                }
                
                if ($app.mountedimageid)
                {
                    $currentstate = $mountarray | where-object {($_.id -eq $app.mountedimageid)}
                    if ($currentstate.imagestate -eq "Mounted")
                    {
                        $mountcommand = 'New-AGMLibMSSQLMigrate -imageid ' +$app.mountedimageid 
                        if ($app.copythreadcount) { $mountcommand = $mountcommand + ' -copythreadcount "' +$app.copythreadcount +'"' } 
                        if ($app.frequency) { $mountcommand = $mountcommand + ' -frequency "' +$app.frequency +'"' } 
                        if ($app.dontrenamedatabasefiles) { $mountcommand = $mountcommand + ' -dontrenamedatabasefiles' } 
                        if ($app.volumes) { $mountcommand = $mountcommand + ' -volumes "' +$app.volumes +'"' } 
                        if ($app.files) { $mountcommand = $mountcommand + ' -files' } 
                        if ($app.restorelist) { $mountcommand = $mountcommand + ' -restorelist "' +$app.restorelist +'"' } 
                    
                        $runcommand = Invoke-Expression $mountcommand
                        $app.previousimagestate = "MigrateStarted" 
                        
                        if ($runcommand.errormessage)
                        { 
                            if ($textoutput)
                            {
                                write-host "The following command encountered this error: " $runcommand.errormessage 
                                $mountcommand
                                write-host ""
                            }
                            else {
                                $printarray += [pscustomobject]@{
                                    appname = $app.appname
                                    appid = $app.appid
                                    result = "failed"
                                    message = $runcommand.errormessage.Trim()
                                    command =  $mountcommand }
                            }
                        }
                        elseif ($runcommand.err_message)
                        { 
                            if ($textoutput)
                            {
                                write-host "The following command encountered this error: " $runcommand.err_message 
                                $mountcommand
                                write-host ""
                            }
                            else {
                                $printarray += [pscustomobject]@{
                                    appname = $app.appname
                                    appid = $app.appid
                                    result = "failed"
                                    message = $runcommand.err_message.Trim()
                                    errorcode = $runcommand.err_code 
                                    command =  $mountcommand }
                            }
                        }
                        else
                        {
                            if ($textoutput)
                            {
                                write-host "The following command started a job"
                                $mountcommand 
                                write-host ""
                            }
                            else 
                            {
                                $printarray += [pscustomobject]@{
                                    appname = $app.appname
                                    appid = $app.appid
                                    result = "started"
                                    message = $runcommand.jobstatus 
                                    command =  $mountcommand }
                            }
                        }
                    }
                }
            }
        }
        $recoverylist | Export-csv -path $runfile
    }
    # run the migration!
    if ($runmigration) 
    {   
        foreach ($app in $recoverylist)
        {
            if ($app.mountedimageid)
            { 
                $migrateruncommand = 'Start-AGMMigrate -imageid ' +$app.mountedimageid
                $runcommand = Invoke-Expression $migrateruncommand 
                
                if ($runcommand.errormessage)
                { 
                    if ($textoutput)
                    {
                        write-host "The following command encountered this error: " $runcommand.errormessage 
                        $mountcommand
                        write-host ""
                    }
                    else {
                        $printarray += [pscustomobject]@{
                            appname = $app.appname
                            appid = $app.appid
                            result = "failed"
                            message = $runcommand.errormessage.Trim()
                            command =  $mountcommand }
                    }
                }
                elseif ($runcommand.err_message)
                { 
                    if ($textoutput)
                    {
                        write-host "The following command encountered this error: " $runcommand.err_message 
                        $mountcommand
                        write-host ""
                    }
                    else {
                        $printarray += [pscustomobject]@{
                            appname = $app.appname
                            appid = $app.appid
                            result = "failed"
                            message = $runcommand.err_message.Trim()
                            errorcode = $runcommand.err_code 
                            command =  $mountcommand }
                    }
                }
                else
                {
                    if ($textoutput)
                    {
                        write-host "The following command started a job"
                        $mountcommand 
                        write-host ""
                    }
                    else 
                    {
                        $printarray += [pscustomobject]@{
                            appname = $app.appname
                            appid = $app.appid
                            result = "started"
                            message = $runcommand.jobstatus 
                            command =  $mountcommand }
                    }
                } 
            }
        }
        $recoverylist | Export-csv -path $runfile
    }

   


    if ($finalizemigration) 
    {
         # we need the mount array in case we dont know the mountimageID
         $activeimagegrab = Get-AGMImage -filtervalue "jobclass=5&jobclass=15&jobclass=19&jobclass=32&jobclass=48&jobclass=59&jobclass=56&jobclass=52&characteristic=1&characteristic=2"
         $mountarray = @()
         # not look throught the mounts for ones that can migrate or are migrating and make an array
         Foreach ($id in $activeimagegrab)
         { 
             $imagestate = ""
             $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.cluster.name
             $id | Add-Member -NotePropertyName hostname -NotePropertyValue $id.host.hostname
             $id | Add-Member -NotePropertyName appid -NotePropertyValue $id.application.id
             $id | Add-Member -NotePropertyName targethostname -NotePropertyValue $id.mountedhost.hostname 
             $id | Add-Member -NotePropertyName targethostid -NotePropertyValue $id.mountedhost.id
             $id | Add-Member -NotePropertyName childappname -NotePropertyValue $id.childapp.appname
             if ( $id.flags_text -contains "JOBFLAGS_FINALIZE_ELIGIBLE")
             {
                 $imagestate = "FinalizeEligible"
             }
             elseif ( $id.flags_text -contains "JOBFLAGS_MIGRATING")
             {
                 $imagestate = "MigrateStarted"
             }
             elseif ( $id.flags_text -contains "MIGRATE_ELIGIBLE")
             {
                 $imagestate = "MigrateElibible"
             }
             elseif ($id.characteristic -eq "Mount")
             {
                 $imagestate = "Mounted"
             }
             else 
             {
                 $imagestate = "Unmounted"
             }
             if ($imagestate)
             {
                 $mountarray += [pscustomobject]@{
                     id = $id.id
                     apptype = $id.apptype
                     appliancename = $id.appliancename
                     hostname = $id.hostname
                     appname = $id.appname
                     targethostname = $id.targethostname
                     targethostid = $id.targethostid
                     childappname = $id.childappname
                     label = $id.label
                     imagestate = $imagestate
                 }
             }
         }
       
        foreach ($app in $recoverylist)
        {
            if ($app.mountedimageid)
            { 
                $currentstate = $mountarray | where-object {($_.id -eq $app.mountedimageid)}
                if ($currentstate.imagestate -eq "FinalizeEligible")
                    {
                    $migrateruncommand = 'Start-AGMMigrate -imageid ' +$app.mountedimageid +' -finalize'
                    $runcommand = Invoke-Expression $migrateruncommand 
                    $app.previousimagestate = "FinalizeStarted" 
                    if ($runcommand.errormessage)
                    { 
                        if ($textoutput)
                        {
                            write-host "The following command encountered this error: " $runcommand.errormessage 
                            $mountcommand
                            write-host ""
                        }
                        else {
                            $printarray += [pscustomobject]@{
                                appname = $app.appname
                                appid = $app.appid
                                result = "failed"
                                message = $runcommand.errormessage.Trim()
                                command =  $mountcommand }
                        }
                    }
                    elseif ($runcommand.err_message)
                    { 
                        if ($textoutput)
                        {
                            write-host "The following command encountered this error: " $runcommand.err_message 
                            $mountcommand
                            write-host ""
                        }
                        else {
                            $printarray += [pscustomobject]@{
                                appname = $app.appname
                                appid = $app.appid
                                result = "failed"
                                message = $runcommand.err_message.Trim()
                                errorcode = $runcommand.err_code 
                                command =  $mountcommand }
                        }
                    }
                    else
                    {
                        if ($textoutput)
                        {
                            write-host "The following command started a job"
                            $mountcommand 
                            write-host ""
                        }
                        else 
                        {
                            $printarray += [pscustomobject]@{
                                appname = $app.appname
                                appid = $app.appid
                                result = "started"
                                message = $runcommand.jobstatus 
                                command =  $mountcommand }
                        }
                    }
                } 
            }
        }
        $recoverylist | Export-csv -path $runfile
    }
}