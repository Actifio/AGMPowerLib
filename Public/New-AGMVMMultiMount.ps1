Function New-AGMLibVMMultiMount ([string]$filename) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of VMware Backups to create new VMware VMs.   This is very similar to New-AGMLibMultiVM but is simpler

    .EXAMPLE
    New-AGMVMMultiMount -filename recoverylist.cav

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibVM jobs

    .DESCRIPTION
    This routine needs a well formatted CSV file.    Here is an example of such a file:

    appid,vmname,datastore,vcenterid,esxhostid,mountmode,poweronvm,onvault,label
    296433,centos2-rec,vsanDatastore,296400,296404,nfs,true,true,multimount
    377723,ubuntu-rec,vsanDatastore,296400,296406,nfs,true,true,multimount
    89091,windows-rec,vsanDatastore,296400,296408,nfs,true,true,multimount

    To get the ingredients for the CSV file, these three commands will let you gather what you need:

    To get the appid use this command:   The VMname is the 'new' name, but clearly you might want it to be a child of the appname:
    Get-AGMApplication -filtervalue apptype=VMBackup | select id,appname,managed

    To get the vCenterID use this command:
    Get-AGMHost -filtervalue isvcenterhost=true | select id,name

    To get the esxhostid use this command.   Consider using a round-robin distribution with the ESX hosts in the list:
    Get-AGMHost -filtervalue isesxhost=true | select id,name
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
    
    if (!($filename))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a csv file correctly formatted as per the help for this function using: -filename xxxx.csv"
        return;
    }

    if ( Test-Path $filename )
    {
        $recoverylist = Import-Csv -Path $filename
    }
    else
    {
        Get-AGMErrorMessage -messagetoprint "VM list: $filename could not be opened."
        return;
    }


    foreach ($app in $recoverylist)
    {
        $mountcommand = 'New-AGMLibVM -appid ' +$app.appid  +' -vmname ' +$app.vmname +' -datastore ' +$app.datastore +' -vcenterid ' +$app.vcenterid +' -esxhostid ' +$app.esxhostid +' -mountmode ' +$app.mountmode 
        if ($app.label) { $mountcommand = $mountcommand + ' -label "' +$app.Label +'"' } 
        if ($app.poweronvm) { $mountcommand = $mountcommand + ' -poweronvm ' + $app.poweronvm } 
        if ($app.onvault) { $mountcommand = $mountcommand + ' -onvault ' + $app.onvault } 
        Invoke-Expression $mountcommand 
    }
}