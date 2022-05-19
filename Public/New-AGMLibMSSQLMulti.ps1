Function New-AGMLibMSSQLMulti ([string]$worklist,[switch]$textoutput) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of GCP Instance data to create many new Microsoft SQLServer Databases

    .EXAMPLE
    New-AGMLibMSSQLMulti -worklist recoverylist.csv 

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibMSSQLMount jobs

    .EXAMPLE
    New-AGMLibMSSQLMulti -worklist recoverylist.csv -textoutput

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibMSSQLMount jobs
    Rather than wait for all jobs to be attemped before reporting status, a report will be displayed after each job is attempted.

    .DESCRIPTION
    This routine needs a well formatted CSV file. The column order is not important.    
    Here is an example of such a file:

    appid,targethostid,mountapplianceid,imagename,imageid,targethostname,appname,sqlinstance,dbname,recoverypoint,recoverymodel,overwrite,label,consistencygroupname,dbnamelist,dbnameprefix,dbrenamelist,dbnamesuffix,recoverdb,userlogins,username,password,base64password,mountmode,mapdiskstoallesxhosts,mountpointperimage,sltid,slpid,discovery
    "50318","51090","143112195179","Image_0089933","59823","win-target","WINDOWS\SQLEXPRESS","WIN-TARGET\SQLEXPRESS","","","Simple","stale","label","cg1","","","model,model1;CRM,CRM1","","false","true","userbname","","cGFzc3dvcmQ=","","","d:\","6717","6667","true"

    If you specify both appanme and appid then appid will be used.  The appname is mandatory so you know the name of the source DB.
    In general you do not want to use the imagename or imageid column (so blank them out of even remove them) because normally we just want the latest image, rather than a specific one.
    For discovery to be requested, add t or true (or any text) to that column.  If any text appears at all, then discovery will be requested.
    

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