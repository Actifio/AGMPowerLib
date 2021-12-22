Function New-AGMLibGCVEfailover ([string]$filename,[int]$phase,[switch][alias("n")]$network) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of VMware VM Names to run mount jobs in phases

    .EXAMPLE
    New-AGMLibGCVEfailover -filename recoverylist.csv -vcenterid XXXXXX

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibVM jobs 

    .DESCRIPTION
    This routine needs a well formatted CSV file.    Here is an example of such a file:

    phase,sourcevmname,targetvmname,label,networkname
    1,WinSrv2019-2,WinSrv2019-2-rec,phase1,avtest
    1,WinSrv2019-3,WinSrv2019-3-rec,phase1,avtest
    2,Centos1,centos1-rec,phase2,avtest
    2,Centos2,centos2-red,phase2,avtest

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
    # phases
    if (!($phase))
    {
        $phase = 1
    }

    if ($network)
    {
        # now we enable the interfaces in the desired interface 
        foreach ($app in $recoverylist)
        {
            if ($app.phase -eq $phase)
            {
                if ($app.networkname.length -gt 0)
                {      
                    write-host "Enabling " $app.targetvmname "in network " $app.networkname
                    get-vm $app.targetvmname  | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $app.networkname -Connected:$false -StartConnected:$true -Confirm:$false
                    Get-VM $app.targetvmname | Get-NetworkAdapter | Select-Object @{N="VM";E={$_.Parent.Name}},@{N="NIC";E={$_.Name}},@{N="Network";E={$_.NetworkName}},@{N="Connected";E={$_.ConnectionState}}
                }
            }
        }
        return
    }


    #  The user can give us a vcenter ID,  but given this is GCVE, we expect we will have only one vCenter.  If we find more than one then we need to know which one
    if (!($vcenterid))
    {
        $vcentergrab =   Get-AGMHost -filtervalue isvcenterhost=true 
        if ($vcentergrab.count -lt 1)
        {
            Get-AGMErrorMessage -messagetoprint "Could not find any vCenters"
            return;
        }
        if ($vcentergrab.counts -gt 1)
        {
            Get-AGMErrorMessage -messagetoprint "Found too many vCenters, please learn the correct ID and specify it wiht -vcenterid"
            return;
        }
        $vcenterid = $vcentergrab.id
        $srcid = $vcentergrab.srcid
        $vcentername = $vcentergrab.name
        write-host ""
        write-host "Using the following vCenter:"
        write-host "Name: $vcentername   vCenterID: $vcenterid"
    }
    # we now create a round robin list of ESX hosts.   We are going to treat them equally
    # firstly we need a srcid from our vcenter
    if (!($srcid))
    {
        $vcentergrab =  Get-AGMHost $vcenterid
        if ($vcentergrab.srcid)
        {
            $srcid = $vcentergrab.srcid
            $vcentername = $vcentergrab.name
            write-host ""
            write-host "Using vCenter named $vcentername with vCenterID $vcenterid"
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Could not find vCenters with ID $vcenterid"
            return;
        }
    }
    $esxgrab = Get-AGMHost -filtervalue "vcenterhostid=$srcid&isesxhost=true&originalhostid=0" 
    if ($esxgrab.count -lt 1)
    {
        Get-AGMErrorMessage -messagetoprint "Could not find ESX hosts for vCenter with ID $vcenterid"
        return;
    }
    # we count the number of ESX hosts
    $esxhostcount = $esxgrab.id.count
    # we start with ESX host index 0
    $esxroundrobin = 0
    write-host ""
    write-host "Using the following ESXi hosts"
    $esxtable = $esxgrab | Select-Object id,name | Format-Table
    $esxtable
    # Our assumption is that GCVE has one datastore and that all ESX hosts have access to that datastore
    $datastoregrab = (((Get-AGMHost $esxgrab.id[0]).sources.datastorelist) | select-object name| sort-object name | Get-Unique -asstring).name
    if ($datastoregrab.count -lt 1)
    {
        Get-AGMErrorMessage -messagetoprint "Could not find any datastores"
        return;
    }
    if ($datastoregrab.count -gt 1)
    {
        Get-AGMErrorMessage -messagetoprint "Found too many datastores"
        return;
    }
    $datastore = $datastoregrab
    write-host ""
    write-host "Using the following Datastore:"
    write-host "$datastore"
    write-host ""
    write-host "Starting Mounts now for phase $phase"


    # we are now ready to go through our list
    foreach ($app in $recoverylist)
    {
        if ($app.phase -eq $phase)
        {
            # so this is the our esxhostid. Starting with index 0  
            $esxhostid = $esxgrab.id[$esxroundrobin]
            $mountcommand = 'New-AGMLibVM -appname ' +$app.sourcevmname  +' -vmname ' +$app.targetvmname +' -datastore ' +$datastore +' -vcenterid ' +$vcenterid +' -esxhostid ' +$esxhostid +' -mountmode nfs  -onvault true'
            if ($app.label) { $mountcommand = $mountcommand + ' -label "' +$app.Label +'"' } 
            write-host "Running $mountcommand"
            Invoke-Expression $mountcommand 
            # we add one to our ESX round robin.   If we hit the hostcount we have gone too far, so 3 hosts means index 0,1,2   so when we get to 3 then we go back to 0
            $esxroundrobin += 1
            if ($esxroundrobin -eq $esxhostcount )
            {
                $esxroundrobin = 0
            }
        }
    }
   


}