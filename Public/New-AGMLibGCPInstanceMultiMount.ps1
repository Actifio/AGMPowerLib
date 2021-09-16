Function New-AGMLibGCPInstanceMultiMount ([string]$instancelist) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of GCP Instance data to create many new GCP Instances

    .EXAMPLE
    New-AGMLibGCPInstanceMultiMount -instancelist recoverylist.cav

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibGCPInstance jobs

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


    foreach ($app in $recoverylist)
    {
        $mountcommand = 'New-AGMLibGCPInstance -appid ' +$app.appid  +' -zone ' +$app.zone +' -projectname ' +$app.projectname +' -machinetype ' +$app.machinetype +' -instancename ' +$app.instancename +' -nic0network "' +$app.nic0network +'" -nic0subnet "' +$app.nic0subnet +'"'
        if ($app.credentialid) { $mountcommand = $mountcommand + ' -credentialid "' +$app.credentialid +'"' } 
        if ($app.srcid) { $mountcommand = $mountcommand + ' -srcid "' +$app.srcid +'"' } 
        if ($app.networktags) { $mountcommand = $mountcommand + ' -networktags "' +$app.networktags +'"' } 
        if ($app.serviceaccount) { $mountcommand = $mountcommand + ' -serviceaccount "' +$app.serviceaccount +'"'} 
        if ($app.labels) { $mountcommand = $mountcommand + ' -labels "' +$app.labels +'"' } 
        if ($app.nic0externalip) { $mountcommand = $mountcommand + ' -nic0externalip ' +$app.nic0externalip } 
        if ($app.nic0internalip) { $mountcommand = $mountcommand + ' -nic0internalip ' +$app.nic0internalip } 
        if ($app.nic1network) { $mountcommand = $mountcommand + ' -nic1network "' +$app.nic1network +'"'} 
        if ($app.nic1subnet) { $mountcommand = $mountcommand + ' -nic1subnet "' +$app.nic1subnet +'"'} 
        if ($app.nic1internalip) { $mountcommand = $mountcommand + ' -nic1internalip ' +$app.nic1internalip } 
        if ($app.nic1externalip) { $mountcommand = $mountcommand + ' -nic1externalip ' +$app.nic1externalip } 
        if ($app.poweronvm) { $mountcommand = $mountcommand + ' -poweronvm ' + $app.poweronvm } 
        if ($app.retainlabel) { $mountcommand = $mountcommand + ' -retainlabel ' + $app.retainlabel } 
        Invoke-Expression $mountcommand 
    }
}