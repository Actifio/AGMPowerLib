Function New-AGMLibMultiVM ([array]$imagelist,[array]$datastorelist,[string]$mountmode,[string]$poweronvm,[array]$esxhostlist,[int]$vcenterid,[string]$mapdiskstoallesxhosts) 
{
    <#
    .SYNOPSIS
    Mounts a number of new VMs

    .EXAMPLE
    New-AGMLibMultiVM -imagelist $imagelist -vcenterid $vcenterid -esxhostlist $esxhostlist -datastorelist $datastorelist -poweronvm false

    This command will use the output of Get-AGMLibImageRange as $imagelist
    The ESXHostlist should be a list of ESX Host IDs
    The Datastorelist should be a list of datastores.
    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }

    if (!($imagelist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an imagelist"
        return
    }
    if (!($datastorelist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a datastorelist as a simple array"
        return
    }
    if (!($esxhostlist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an esxhostlist as a simple array"
        return
    }
    if (!($vcenterid))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a vcenterid"
        return
    }
   

    if (!($mountmode))
    {
        $physicalrdm = 0
        $rdmmode = "independentvirtual"
    }
    else 
    {
        if ($mountmode -eq "vrdm")
        {
            $physicalrdm = 0
            $rdmmode = "independentvirtual"
        }
        if ($mountmode -eq "prdm")
        {
            $physicalrdm = 1
            $rdmmode = "physical"
        }
        if ($mountmode -eq "nfs")
        {
            $physicalrdm = 2
            $rdmmode = "nfs"
        }
    }

    if (!($poweronvm))
    {
        $poweronvm = "true"
    }
    if (($poweronvm -ne "true") -and  ($poweronvm -ne "false"))
    {
        Get-AGMErrorMessage -messagetoprint "Power on VM value of $poweronvm is not valid.  Must be true or false"
        return
    }

    if (!($mapdiskstoallesxhosts))
    {
        $mapdiskstoallesxhosts = "false"
    }
    if (($mapdiskstoallesxhosts -ne "true") -and  ($mapdiskstoallesxhosts -ne "false"))
    {
        Get-AGMErrorMessage -messagetoprint "The value of Map to all ESX hosts of $mapdiskstoallesxhosts is not valid.  Must be true or false"
        return
    }

    if (!($label))
    {
        $label = "MultiVM Recovery"
    }

    $esxhostcount = $esxhostlist.count
    $datastorecount = $datastorelist.count
    $esxroundrobin = 0
    $dsroundrobin = 0

    foreach ($image in $imagelist)
    {
        $vmname = $image.appname + "_" + $image.backupname
        $imageid = $image.id
        $esxhostid = $esxhostlist[$esxroundrobin]
        $datastore = $datastorelist[$dsroundrobin]
        $body = [ordered]@{
            "@type" = "mountRest";
            label = "$label"
            restoreoptions = @(
                @{
                    name = 'mapdiskstoallesxhosts'
                    value = "$mapdiskstoallesxhosts"
                }
            )
            datastore = $datastore;
            hypervisor = @{id=$esxhostid}
            mgmtserver = @{id=$vcenterid}
            vmname = $vmname;
            hostname = $vmname;
            poweronvm = "$poweronvm";
            physicalrdm = $physicalrdm;
            rdmmode = $rdmmode;
            migratevm = "false";
        }
        $json = $body | ConvertTo-Json
        Write-Host "Mounting AppName:" $image.appname "ImageName:" $image.backupname "ConsistencyDate:" $image.consistencydate
        Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json
        $esxroundrobin += 1
        $dsroundrobin += 1
        if ($esxroundrobin -eq $esxhostcount )
        {
            $esxroundrobin = 0
        }
        if ($dsroundrobin -eq $datastorecount )
        {
            $dsroundrobin = 0
        }
    }
}