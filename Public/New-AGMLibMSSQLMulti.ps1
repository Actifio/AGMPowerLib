Function New-AGMLibMSSQLMulti ([string]$worklist,[switch]$textoutput,[switch]$runmount,[switch]$runmigration,[switch]$startmigration,[switch]$finalizemigration) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of SQL DBs or Instances to create many new Microsoft SQLServer Databases

    .EXAMPLE
    New-AGMLibMSSQLMulti -worklist recoverylist.csv -runmount

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibMSSQLMount jobs

    .EXAMPLE
    New-AGMLibMSSQLMulti -worklist recoverylist.csv -textoutput -runmount

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibMSSQLMount jobs
    Rather than wait for all jobs to be attemped before reporting status, a report will be displayed after each job is attempted.

    .EXAMPLE
    New-AGMLibMSSQLMulti -worklist recoverylist.csv -startmigration

    This will load the contents of the file recoverylist.csv and use it to start multiple migrate jobs for any SQL Db where migrate=true
    
    .EXAMPLE
    New-AGMLibMSSQLMulti -worklist recoverylist.csv -runmigration

    This will load the contents of the file recoverylist.csv and use it to run a migration job for each DB that has a started migration
    
    .EXAMPLE
    New-AGMLibMSSQLMulti -worklist recoverylist.csv -finalizemigration

    This will load the contents of the file recoverylist.csv and use it to finalize the migration for each DB that has a started migration



    .DESCRIPTION
    This routine needs a well formatted CSV file. The column order is not important.    
    Here is an example of such a file:

    appid,targethostid,mountapplianceid,imagename,imageid,targethostname,appname,sqlinstance,dbname,recoverypoint,recoverymodel,overwrite,label,consistencygroupname,dbnamelist,dbnameprefix,dbrenamelist,dbnamesuffix,recoverdb,userlogins,username,password,base64password,mountmode,mapdiskstoallesxhosts,mountpointperimage,sltid,slpid,discovery,migrate,copythreadcount,frequency,dontrenamedatabasefiles,volumes,files,restorelist
    "50318","51090","143112195179","Image_0089933","59823","win-target","WINDOWS\SQLEXPRESS","WIN-TARGET\SQLEXPRESS","","","Simple","stale","label","cg1","","","model,model1;CRM,CRM1","","false","true","userbname","","cGFzc3dvcmQ=","","","d:\","6717","6667","true"

    If you specify both appanme and appid then appid will be used.  The appname is mandatory so you know the name of the source DB.
    In general you do not want to use the imagename or imageid column (so blank them out of even remove them) because normally we just want the latest image, rather than a specific one.
    For discovery to be requested, add t or true (or any text) to that column.  If any text appears at all, then discovery will be requested.

    The following columns are used for migration:
    migrate,copythreadcount,frequency,dontrenamedatabasefiles,volumes,files,restorelist
     
    migrate (switch) - Left blank:  no migration.  Set (any character):  image will be migrated
    copythreadcount (integer) -  Left blank:  4 threads else set a number of threads   
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
    
    if (!($worklist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a csv file correctly formatted as per the help for this function using: -worklist xxxx.csv"
        return;
    }

    if ( Test-Path $worklist )
    {
        $recoverylist = Import-Csv -Path $worklist
    }
    else
    {
        Get-AGMErrorMessage -messagetoprint "SQL DB list: $worklist could not be opened."
        return;
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

            $runcommand = Invoke-Expression $mountcommand 
            
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
        
        if (!($textoutput))
        {
            $printarray
        }
    }
    # start the migration!
    if ($startmigration) 
    {
    
        # migration time   [string]$imagename,[string]$imageid,[int]$copythreadcount,[int]$frequency,[switch]$dontrenamedatabasefiles,[switch]$volumes,[switch]$files,[string]$restorelist
        foreach ($app in $recoverylist)
        {
            if ($app.migrate)
            {
            
                $imagename = ""
                # find the imagename of the image created by the mount

                #  stuff we can search on appid,targethostid,mountapplianceid,imagename,imageid,targethostname,appname,sqlinstance,dbname,recoverypoint,recoverymodel,overwrite,label,consistencygroupname

                $fv = "characteristic=1&characteristic=2&apptype!nas"
                if ($app.appid) 
                {
                    $fv = $fv + "&appid=" +$app.appid
                }
                if ($app.appname) 
                {
                    $fv = $fv + "&appname=" +$app.appname
                }
                if ($app.label)
                {
                    $fv = $fv + "&label=" +$app.label
                }
                if ($app.mountapplianceid)
                {
                    $fv = $fv + "&targetuds=" +$app.mountapplianceid
                }
                if ($app.targethostid)
                {
                    # try and find source ID

                    $hostfilter = "clusterid=" +$app.mountapplianceid +"&id=" +$app.targethostid
                    $hostgrab = Get-AGMHost -filtervalue "$hostfilter"
                    if ($hostgrab.count.id -eq 1)
                    {
                        $sourceid = $hostgrab.sources.srcid
                        $fv = $fv + "&mountedhost=" +$sourceid
                    }
                } elseif ($app.targethostname)
                {
                     # try and find source ID

                     $hostfilter = "clusterid=" +$app.mountapplianceid +"&name=" +$app.targethostname
                     $hostgrab = Get-AGMHost -filtervalue "$hostfilter"
                     if ($hostgrab.count.id -eq 1)
                     {
                         $sourceid = $hostgrab.sources.srcid
                         $fv = $fv + "&mountedhost=" +$sourceid
                     }
                }
               
                $imagegrab = Get-AGMImage -filtervalue "$fv" 
                if ($imagegrab.backupname.count -eq 1)
                {
                    $imageid = $imagegrab.id
                }
                if ($imageid)
                {
                    $app.mountedimageid = $imageid
                    $mountcommand = 'New-AGMLibMSSQLMigrate -imageid ' +$imageid 
                    if ($app.copythreadcount) { $mountcommand = $mountcommand + ' -copythreadcount "' +$app.copythreadcount +'"' } 
                    if ($app.frequency) { $mountcommand = $mountcommand + ' -frequency "' +$app.frequency +'"' } 
                    if ($app.dontrenamedatabasefiles) { $mountcommand = $mountcommand + ' -dontrenamedatabasefiles' } 
                    if ($app.volumes) { $mountcommand = $mountcommand + ' -volumes "' +$app.volumes +'"' } 
                    if ($app.files) { $mountcommand = $mountcommand + ' -files' } 
                    if ($app.restorelist) { $mountcommand = $mountcommand + ' -restorelist "' +$app.restorelist +'"' } 
                
                    $runcommand = Invoke-Expression $mountcommand 
                    
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
        $recoverylist | Export-csv -path $worklist
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
    }
    if ($finalizemigration) 
    {
    
       
        foreach ($app in $recoverylist)
        {
            if ($app.mountedimageid)
            { 
                $migrateruncommand = 'Start-AGMMigrate -imageid ' +$app.mountedimageid +' -finalize'
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
    }
}