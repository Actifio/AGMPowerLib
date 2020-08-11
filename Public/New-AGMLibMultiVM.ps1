Function New-AGMLibMultiVM ([array]$imagelist,$vcenterid,[array]$esxhostlist,[array]$datastorelist,[string]$datastore,[int]$esxhostid,[string]$prefix,[string]$mountmode,[string]$poweronvm,[string]$mapdiskstoallesxhosts,[string]$label) 
{
    <#
    .SYNOPSIS
    Mounts a number of new VMs

    .EXAMPLE
    New-AGMLibMultiVM -imagelist $imagelist -vcenterid $vcenterid -esxhostlist $esxhostlist -datastorelist $datastorelist -poweronvm false -prefix "recover-"

    This command will use the output of Get-AGMLibImageRange as $imagelist
    The ESXHostlist should be a list of ESX Host IDs
    The Datastorelist should be a list of datastores.
    The prefix is optional but recommended
    By default it will add the Image Name as a suffix since this gives a degree of uniqueness
    By default it will use a label of "MultiVM Recovery" to make the VMs easier to find

    .EXAMPLE
    New-AGMLibMultiVM -imagelist $imagelist -vcenterid $vcenterid -esxhosttid $esxhostid -datastore $datastore -poweronvm false -prefix "recover-"
    
    If you only have a single ESX host and Datastore you can specify them singly using -esxhostid and -datastore
    Clearly all your mounts will go to a single ESX Host and datastore

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }

    # handle vcenterid
    if ($vcenterid.id)
    {
        if ($vcenterid.id.count -gt 1)
        {
            Get-AGMErrorMessage -messagetoprint "There is more than vCenterID specified.  This function can only use one vCenterID"
            return
        }
        else 
        {
            $vcenterid = $vcenterid.id            
        }
     }

    # handle esxlist
    if ($esxhostlist.id)
    {
        $esxhostlist = ($esxhostlist).id 
    }
    if ( (!($esxhostlist)) -and ($esxhostid) )
    {
        $esxhostlist = $esxhostid
    }

    # handle datastorelist
    if ($datastorelist.name)
    {
        $datastorelist = ($datastorelist).name | Get-Unique -asstring
    }
    if ( (!($datastorelist)) -and ($datastore) )
    {
        $datastorelist = $datastore
    }


    if (!($imagelist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an imagelist"
        return
    }
    if (!($datastorelist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an array of datastores using -datastorelist or a single datastore using -datastore"
        return
    }
    if (!($esxhostlist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an array of ESXHost IDs using -esxhostlist or a single ESX Host ID using -esxhostid"
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
    $lastappid = ""
    $lastcondate = ""

    foreach ($image in $imagelist)
    {
        $vmname = $image.appname + "_" + $image.backupname
        if ($prefix)
        {
            $vmname = $prefix + $vmname
        }
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
        if (($lastappid -eq $image.appid) -and ($lastcondate -eq $image.consistencydate))
        {
            Write-Host "Not mounting AppName:" $image.appname " Jobclass:" $image.jobclass " ImageName:" $image.backupname " ConsistencyDate:" $image.consistencydate "because the previous mount had the same appid and consistency date" 
        }
        elseif ($image.apptype -eq "VMBackup")
        {
            Write-Host "    Mounting AppName:" $image.appname " Jobclass:" $image.jobclass " ImageName:" $image.backupname " ConsistencyDate:" $image.consistencydate "as:" $vmname "to ESX Host ID" $esxhostid "using Datastore" $datastore
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
            $lastappid = $image.appid
            $lastcondate = $image.consistencydate
        }
        else 
        {
            Write-Host "******* Not mounting AppName:" $image.appname "ImageName:" $image.backupname "because it has an apptype of" $image.apptype "*******"
        }
    }
}