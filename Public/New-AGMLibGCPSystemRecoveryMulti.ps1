Function New-AGMLibGCPSystemRecoveryMulti ([string]$instancelist,[int]$phase) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of GCP Instance data to create many new GCP Instances from System State or VMware VM backups

    .EXAMPLE
    New-AGMLibGCPSystemRecoveryMulti -instancelist recoverylist.csv -phase 1

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibGCPSystemRecovery jobs

    .DESCRIPTION
    This routine needs a well formatted CSV file.    Here is an example of such a file:

    phase,srcid,appid,projectname,sharedvpcprojectid,region,zone,instancename,machinetype,serviceaccount,nodegroup,networktags,poweroffvm,migratevm,labels,nic0network,nic0subnet,nic0externalip,nic0internalip,nic1network,nic1subnet,nic1externalip,nic1internalip,preferedsource,disktype
    1,391360,296433,avwlab2,,australia-southeast1,australia-southeast1-a,newinstance,n2-highmem-16,systemstaterecovery@avwlab2.iam.gserviceaccount.com,,"http,https",true,true,"pet:cat,food:fish",https://www.googleapis.com/compute/v1/projects/avwlab2/global/networks/default,https://www.googleapis.com/compute/v1/projects/avwlab2/regions/australia-southeast1/subnetworks/default,auto,,,,,,onvault,pd-standard
     

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


    foreach ($app in $recoverylist)
    {
        if ($app.phase -eq $phase)
        {
            $mountcommand = 'New-AGMLibGCPSystemRecovery -appid ' +$app.appid  +' -projectname ' +$app.projectname +' -machinetype ' +$app.machinetype +' -instancename ' +$app.instancename +' -nic0network "' +$app.nic0network +'" -nic0subnet "' +$app.nic0subnet +'"'
            $mountcommand = $mountcommand + ' -region "' +$app.region +'"' 
            $mountcommand = $mountcommand + ' -zone "' +$app.zone +'"' 
            $mountcommand = $mountcommand + ' -srcid "' +$app.srcid +'"' 
            $mountcommand = $mountcommand + ' -serviceaccount "' +$app.serviceaccount +'"' 
            if ($app.nodegroup) { $mountcommand = $mountcommand + ' -nodegroup "' +$app.nodegroup +'"' } 
            if ($app.networktags) { $mountcommand = $mountcommand + ' -networktags "' +$app.networktags +'"' } 
            if ($app.labels) { $mountcommand = $mountcommand + ' -labels "' +$app.labels +'"' } 
            if ($app.nic0externalip) { $mountcommand = $mountcommand + ' -nic0externalip ' +$app.nic0externalip } 
            if ($app.nic0internalip) { $mountcommand = $mountcommand + ' -nic0internalip ' +$app.nic0internalip } 
            if ($app.nic1network) { $mountcommand = $mountcommand + ' -nic1network "' +$app.nic1network +'"'} 
            if ($app.nic1subnet) { $mountcommand = $mountcommand + ' -nic1subnet "' +$app.nic1subnet +'"'} 
            if ($app.nic1internalip) { $mountcommand = $mountcommand + ' -nic1internalip ' +$app.nic1internalip } 
            if ($app.nic1externalip) { $mountcommand = $mountcommand + ' -nic1externalip ' +$app.nic1externalip } 
            if ($app.poweronvm -eq "true") { $mountcommand = $mountcommand + ' -poweronvm ' + $app.poweronvm } 
            if ($app.migratevm -eq "true") { $mountcommand = $mountcommand + ' -retainlabel ' + $app.retainlabel } 
            if ($app.preferedsource) { $mountcommand = $mountcommand + ' -preferedsource ' +$app.preferedsource } 
            if ($app.disktype) { $mountcommand = $mountcommand + ' -disktype ' +$app.disktype } 
            Invoke-Expression $mountcommand 
        }
    }
}