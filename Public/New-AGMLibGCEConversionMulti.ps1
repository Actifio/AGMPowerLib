Function New-AGMLibGCEConversionMulti ([string]$instancelist,[switch]$textoutput) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of GCP Instance data to create many new GCP Instances from System State or VMware VM backups

    .EXAMPLE
    New-AGMLibGCEConversionMulti -instancelist recoverylist.csv 

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibGCEConversion jobs

    .EXAMPLE
    New-AGMLibGCEConversionMulti -instancelist recoverylist.csv -textoutput

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibGCEConversion jobs
    Rather than wait for all jobs to be attemped before reporting status, a report will be displayed after each job is attempted.

    .DESCRIPTION
    This routine needs a well formatted CSV file. The column order is not important.    
    Here is an example of such a file:

    srcid,appid,appname,projectname,sharedvpcprojectid,region,zone,instancename,machinetype,serviceaccount,nodegroup,networktags,poweroffvm,migratevm,labels,preferedsource,disktype,nic0network,nic0subnet,nic0externalip,nic0internalip,nic1network,nic1subnet,nic1externalip,nic1internalip
    391360,296433,"Centos2","project1","hostproject1","europe-west2","europe-west2-a","newvm1","n1-standard-2","systemstaterecovery@project1.iam.gserviceaccount.com","nodegroup1","https-server",False,True,status:failover,onvault,pd-standard,https://www.googleapis.com/compute/v1/projects/project1/global/networks/actifioanz,https://www.googleapis.com/compute/v1/projects/project1/regions/europe-west2/subnetworks/default,auto,,https://www.googleapis.com/compute/v1/projects/project1/global/networks/default,https://www.googleapis.com/compute/v1/projects/project1/regions/europe-west2/subnetworks/default,,  
    
    If you specify both appanme and appid then appid will be used.  The appname is mandatory so you know the name of the source VM.

    Note that the the labels and networktags fields can contain commas, so need to be double quoted to ensure they do no escape the wrong field
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
    
    if (!($instancelist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a csv file correctly formatted as per the help for this function using: -instancelist xxxx.csv"
        return;
    }

    if ( Test-Path $instancelist )
    {
        $recoverylist = Import-Csv -Path $instancelist
    }
    else
    {
        Get-AGMErrorMessage -messagetoprint "GCP Instance list: $instancelist could not be opened."
        return;
    }

    # first we quality check the CSV
    if ($recoverylist.srcid -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: srcid" ;return }
    if ($recoverylist.projectname -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: projectname" ;return }
    if ($recoverylist.machinetype -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: machinetype" ;return }
    if ($recoverylist.instancename -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: instancename" ;return }
    if ($recoverylist.nic0network -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: nic0network" ;return }
    if ($recoverylist.nic0subnet -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: nic0subnet" ;return }
    if ($recoverylist.region -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: region" ;return }
    if ($recoverylist.zone -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: zone" ;return }
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
        if ($app.srcid -eq "") { write-host  "The following mandatory value is missing: srcid in row $row" ; return }
        $row += 1
    }
    $row =1
    foreach ($app in $recoverylist)
    {
        if ($app.appname -eq "")  { write-host "The following mandatory value is missing: appname row $row" ; return}
        $row += 1
    }
    



    foreach ($app in $recoverylist)
    {

        $mountcommand = 'New-AGMLibGCEConversion -projectname ' +$app.projectname +' -machinetype ' +$app.machinetype +' -instancename "' +$app.instancename +'" -nic0network "' +$app.nic0network +'" -nic0subnet "' +$app.nic0subnet +'"'
        $mountcommand = $mountcommand + ' -region "' +$app.region +'"' 
        $mountcommand = $mountcommand + ' -zone "' +$app.zone +'"' 
        $mountcommand = $mountcommand + ' -srcid "' +$app.srcid +'"' 
        if (($app.appname) -and ($app.appid)) { $mountcommand = $mountcommand + ' -appid "' +$app.appid +'"' }
        if (($app.appname) -and (!($app.appid))) {  $mountcommand = $mountcommand + ' -appname "' +$app.appname +'"' }
        if ((!($app.appname)) -and ($app.appid)) { $mountcommand = $mountcommand + ' -appid "' +$app.appid +'"' }
        if ($app.sharedvpcprojectid) { $mountcommand = $mountcommand + ' -sharedvpcprojectid "' +$app.sharedvpcprojectid +'"' } 
        if ($app.serviceaccount) { $mountcommand = $mountcommand + ' -serviceaccount "' +$app.serviceaccount +'"' } 
        if ($app.nodegroup) { $mountcommand = $mountcommand + ' -nodegroup "' +$app.nodegroup +'"' } 
        if ($app.networktags) { $mountcommand = $mountcommand + ' -networktags "' +$app.networktags +'"' } 
        if ($app.labels) { $mountcommand = $mountcommand + ' -labels "' +$app.labels +'"' } 
        if ($app.poweronvm -eq "true") { $mountcommand = $mountcommand + ' -poweronvm ' + $app.poweronvm } 
        if ($app.migratevm -eq "true") { $mountcommand = $mountcommand + ' -retainlabel ' + $app.retainlabel } 
        if ($app.preferedsource) { $mountcommand = $mountcommand + ' -preferedsource ' +$app.preferedsource } 
        if ($app.disktype) { $mountcommand = $mountcommand + ' -disktype ' +$app.disktype } 
        if ($app.nic0externalip) { $mountcommand = $mountcommand + ' -nic0externalip ' +$app.nic0externalip } 
        if ($app.nic0internalip) { $mountcommand = $mountcommand + ' -nic0internalip ' +$app.nic0internalip } 
        if ($app.nic1network) { $mountcommand = $mountcommand + ' -nic1network "' +$app.nic1network +'"'} 
        if ($app.nic1subnet) { $mountcommand = $mountcommand + ' -nic1subnet "' +$app.nic1subnet +'"'} 
        if ($app.nic1internalip) { $mountcommand = $mountcommand + ' -nic1internalip ' +$app.nic1internalip } 
        if ($app.nic1externalip) { $mountcommand = $mountcommand + ' -nic1externalip ' +$app.nic1externalip }         

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
                    instancename = $app.instancename
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
                    instancename = $app.instancename
                    result = "failed"
                    message = $runcommand.err_message.Trim()
                    errorcode = $runcommand.err_code 
                    command =  $mountcommand }
            }
        }
        elseif ($runcommand.jobstatus)
        {
            if ($textoutput)
            {
                write-host "The following command started this job: " $runcommand.jobstatus
                $mountcommand 
                write-host ""
            }
            else 
            {
                $printarray += [pscustomobject]@{
                    appname = $app.appname
                    appid = $app.appid
                    instancename = $app.instancename
                    result = "started"
                    message = $runcommand.jobstatus 
                    command =  $mountcommand }
            }
        }
        else
        {
            if ($textoutput)
            {
                write-host "The following command may not have started: " $runcommand
                $mountcommand 
                write-host ""
            }
            else {
                $printarray += [pscustomobject]@{
                    appname = $app.appname
                    appid = $app.appid
                    instancename = $app.instancename
                    result = "unknown"
                    command =  $mountcommand }
            }
        }
    }
       
    if (!($textoutput))
    {
        $printarray
    }
}