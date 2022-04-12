Function New-AGMLibGCPInstanceMultiMount ([string]$instancelist,[switch]$textoutput) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of GCP Instance data to create many new GCP Instances

    .EXAMPLE
    New-AGMLibGCPInstanceMultiMount -instancelist recoverylist.csv

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibGCPInstance jobs

    .EXAMPLE
    New-AGMLibGCPInstanceMultiMount -instancelist recoverylist.csv -textoutput

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibGCPInstance jobs
    Rather than wait for all jobs to be attemped before reporting status, a report will be displayed after each job is attempted.

    .DESCRIPTION
    This routine needs a well formatted CSV file.    Here is an example of such a file:

    appid,srcid,projectname,zone,instancename,machinetype,serviceaccount,networktags,labels,nic0network,nic0subnet,nic0externalip,nic0internalip,nic1network,nic1subnet,nic1externalip,nic1internalip,disktype,poweronvm,retainlabel
    35590,28417,prodproject1,australia-southeast1-c,tinym,e2-micro,,"http-server,https-server","dog:cat,sheep:cow",https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/default,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/default,,, ,,,,pd-balanced,TRUE,TRUE
    51919,28417,prodproject1,australia-southeast1-c,mysqlsourcem,e2-medium,,,,https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/default,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/default,auto,,https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/actifioanz,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/australia,auto,10.186.0.200,,,TRUE
    36104,28417,prodproject1,australia-southeast1-c,mysqltargetm,e2-medium,,,,https://www.googleapis.com/compute/v1/projects/prodproject1/global/networks/default,https://www.googleapis.com/compute/v1/projects/prodproject1/regions/australia-southeast1/subnetworks/default,,10.152.0.200,,,,,pd-ssd,TRUE,TRUE
   
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
    if ($recoverylist.zone -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: zone" ;return }
    if (($recoverylist.appname -eq $null) -and ($recoverylist.appid -eq $null))  {  Get-AGMErrorMessage -messagetoprint "Could not find either appid or appname columns" ; return }



    write-host ""
    if (!($textoutput))
    {
        $printarray = @()
    }
    $row = 1
    foreach ($app in $recoverylist)
    {
        $badrowmesssage = ""
        if ($app.srcid -eq "") { $badrowmesssage =  "The following mandatory value is missing: srcid in row $row" }
        if ($app.projectname -eq "") { $badrowmesssage = "The following mandatory value is missing: projectname row $row" }
        if ($app.machinetype -eq "") { $badrowmesssage = "The following mandatory value is missing: machinetype row $row" }
        if ($app.instancename -eq "") { $badrowmesssage = "The following mandatory value is missing: instancename row $row" }
        if ($app.nic0network -eq "") { $badrowmesssage = "The following mandatory value is missing: nic0network row $row" }
        if ($app.nic0subnet -eq "") { $badrowmesssage = "The following mandatory value is missing: nic0subnet row $row" }
        if ($app.zone.count -eq 0) { $badrowmesssage = "The following mandatory value is missing: zone row $row" }
        if (($app.appname -eq "") -and ($app.appid -eq ""))  { $badrowmesssage = "Could not find either appid or appname value in row $row" }

        $mountcommand = 'New-AGMLibGCPInstance -srcid ' +$app.srcid +' -zone ' +$app.zone +' -projectname ' +$app.projectname +' -machinetype ' +$app.machinetype +' -instancename ' +$app.instancename +' -nic0network "' +$app.nic0network +'" -nic0subnet "' +$app.nic0subnet +'"'
        if ($app.appid) { $mountcommand = $mountcommand + ' -appid "' +$app.appid +'"' }
        if ($app.appname) {  $mountcommand = $mountcommand + ' -appname "' +$app.appname +'"' }
        if ($app.networktags) { $mountcommand = $mountcommand + ' -networktags "' +$app.networktags +'"' } 
        if ($app.serviceaccount) { $mountcommand = $mountcommand + ' -serviceaccount "' +$app.serviceaccount +'"'} 
        if ($app.labels) { $mountcommand = $mountcommand + ' -labels "' +$app.labels +'"' } 
        if ($app.nic0externalip) { $mountcommand = $mountcommand + ' -nic0externalip ' +$app.nic0externalip } 
        if ($app.nic0internalip) { $mountcommand = $mountcommand + ' -nic0internalip ' +$app.nic0internalip } 
        if ($app.nic1network) { $mountcommand = $mountcommand + ' -nic1network "' +$app.nic1network +'"'} 
        if ($app.nic1subnet) { $mountcommand = $mountcommand + ' -nic1subnet "' +$app.nic1subnet +'"'} 
        if ($app.nic1internalip) { $mountcommand = $mountcommand + ' -nic1internalip ' +$app.nic1internalip } 
        if ($app.nic1externalip) { $mountcommand = $mountcommand + ' -nic1externalip ' +$app.nic1externalip } 
        if ($app.nic2network) { $mountcommand = $mountcommand + ' -nic2network "' +$app.nic2network +'"'} 
        if ($app.nic2subnet) { $mountcommand = $mountcommand + ' -nic2subnet "' +$app.nic2subnet +'"'} 
        if ($app.nic2internalip) { $mountcommand = $mountcommand + ' -nic2internalip ' +$app.nic2internalip } 
        if ($app.nic2externalip) { $mountcommand = $mountcommand + ' -nic2externalip ' +$app.nic2externalip } 
        if ($app.nic3network) { $mountcommand = $mountcommand + ' -nic3network "' +$app.nic3network +'"'} 
        if ($app.nic3subnet) { $mountcommand = $mountcommand + ' -nic3subnet "' +$app.nic3subnet +'"'} 
        if ($app.nic3internalip) { $mountcommand = $mountcommand + ' -nic3internalip ' +$app.nic3internalip } 
        if ($app.nic3externalip) { $mountcommand = $mountcommand + ' -nic3externalip ' +$app.nic3externalip } 
        if ($app.poweronvm) { $mountcommand = $mountcommand + ' -poweronvm ' + $app.poweronvm } 
        if ($app.retainlabel) { $mountcommand = $mountcommand + ' -retainlabel ' + $app.retainlabel } 
        if ($badrowmesssage -eq "") 
        {
            $runcommand = Invoke-Expression $mountcommand 
        }
        if ($badrowmesssage -ne "") 
        {
            if ($textoutput)
            {
                write-host "The following command encountered this error: " $badrowmesssage
                $mountcommand
                write-host ""
            }
            else {
                $printarray += [pscustomobject]@{
                    appname = $app.appname
                    appid = $app.appid
                    result = "failed"
                    message = $badrowmesssage
                    command =  $mountcommand }
            }
        }
        elseif ($runcommand.errormessage)
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
                    message = $runcommand.errormessage 
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
                    message = $runcommand.err_message
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
                    result = "unknown"
                    command =  $mountcommand }
            }
        }
        $row += 1
    }
       
    if (!($textoutput))
    {
        $printarray
    }
}