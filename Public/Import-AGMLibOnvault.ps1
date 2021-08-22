Function Import-AGMLibOnVault([string]$diskpoolid,[string]$applianceid,[string]$appid,[switch][alias("f")]$forget,[switch][alias("o")]$ownershiptakeover) 
{
    <#
    .SYNOPSIS
    Imports or forgets OnVault images
    There is no Forget-AGMOnVault command.   You can do import and forget from this function. 

    .EXAMPLE
    Import-AGMLibOnvault -diskpoolid 20060633 -applianceid 1415019931 

    Imports all OnVault images from disk pool ID 20060633 onto Appliance ID 1415019931

    .EXAMPLE
    Import-AGMLibOnVault -diskpoolid 20060633 -applianceid 1415019931 -appid 4788
    
    Imports all OnVault images from disk pool ID 20060633 and App ID 4788 onto Appliance ID 1415019931

    .EXAMPLE
    Import-AGMLibOnVault -diskpoolid 20060633 -applianceid 1415019931 -appid 4788 -owner
    
    Imports all OnVault images from disk pool ID 20060633 and App ID 4788 onto Appliance ID 1415019931 and takes ownership

    .EXAMPLE
    Import-AGMLibOnVault -diskpoolid 20060633 -applianceid 1415019931 -appid 4788 -forget
    
    Forgets all OnVault images imported from disk pool ID 20060633 and App ID 4788 onto Appliance ID 1415019931

    .DESCRIPTION
    A function to import OnVault images

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    else 
    {
        $sessiontest = (Get-AGMSession).session_id
        if ($sessiontest -ne $AGMSESSIONID)
        {
            Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
            return
        }
    }

    if ((!($diskpoolid)) -or (!($applianceid)))
    {

        Write-Host "This function is used to import Onvault images into an Appliance."
        Write-host "We need to determine which pool to import from and which appliance created the images to import"
        Write-host "If importing we also need to decide whether the importing appliance (which owns the selected pool) should take ownership of the imported images"
        Write-host "Alternatively we can decide to have the appliance forget any previously imported images, rather than discover new ones"
        Write-host ""

        $diskpoolgrab = Get-AGMDiskPool -filtervalue pooltype=vault -sort name:asc
        if ($diskpoolgrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any disk pools to list"
            return
        }
        if ($diskpoolgrab.count -eq 1)
        {
            $diskpoolid = $diskpoolgrab.id
            write-host "Only one OnVault diskpool was found.  We will use this one:"  $diskpoolgrab.name 
        }
        else
        {
            write-host "Pool selection menu - which Diskpool we will use (which also determines which Appliance we use)"
            Write-host ""
            $i = 1
            foreach ($pool in $diskpoolgrab)
            { 
                Write-Host -Object "$i`: $($pool.name) on $($pool.cluster.name)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $diskpoolgrab.name.count
                [int]$poolselection = Read-Host "Please select a Diskpool to import from (1-$listmax)"
                if ($poolselection -lt 1 -or $poolselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $diskpoolid =  $diskpoolgrab.id[($poolselection - 1)]
        }
        

        write-host "Inspecting the disk pool for source appliances"
        write-host ""
        $appliancegrab = Get-AGMAPIData  -endpoint /diskpool/$diskpoolid/vaultclusters
        if ($appliancegrab.cluster.clusterid.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any appliances to list"
            return
        }
        if ($appliancegrab.cluster.clusterid.count -eq 1)
        {
            $applianceid = $appliancegrab.cluster.clusterid
            write-host "Only one Appliance was found.  We will use this one:"  $appliancegrab.cluster.name
        }
        else
        {
            write-host "Appliance selection menu - which Appliance will we import from"
            Write-host ""
            $i = 1
            foreach ($appliance in $appliancegrab.cluster)
            { 
                Write-Host -Object "$i`: $($appliance.name)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $appliancegrab.cluster.name.count
                [int]$appselection = Read-Host "Please select an Appliance to import into (1-$listmax)"
                if ($appselection -lt 1 -or $appselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $applianceid =  $appliancegrab.cluster.clusterid[($appselection - 1)]
        }
        
        Write-Host ""
        Write-Host "Do you want to have the selected appliance take ownership of any images.   Default is no"
        Write-Host ""
        Write-Host "1`: Don't take ownership (default)"
        Write-Host "2`: Take ownership"
        $ownerchoice = Read-Host "Please select from this list (1-2)"
        if ($ownerchoice -eq 2) { $owner = $true}
        Write-Host ""
        Write-Host "Do you want to have the selected appliance forget any discovered images.   Default is no"
        Write-Host ""
        Write-Host "1`: Don't forget discovered images (default)"
        Write-Host "2`: Forget images"
        $forgetchoice = Read-Host "Please select from this list (1-2)"
        if ($forgetchoice -eq 2) { $forget = $true}
        
        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline "Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid"  
        if ($forget) { Write-Host -nonewline " -forget" }
        if ($owner) { Write-Host -nonewline " -owner" }
        if ($appid) { Write-Host -nonewline " -appid $appid" }
        Write-Host ""
        Write-Host "1`: Run the command now"
        Write-Host "2`: Exit without running the command (default)"
        $appuserchoice = Read-Host "Please select from this list (1-2)"
        if ($appuserchoice -eq "") { $appuserchoice = 2}
        if ($appuserchoice -eq 2)
        {
            return
        }



    }

    if ($appid)
    {
        if ($owner)
        {
            Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -appid $appid -owner
        }
        elseif ($forget)
        {
            Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -appid $appid -forget
        }
        else 
        {
            Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -appid $appid 
        }
    }
    else {
        if ($owner)
        {
            Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -owner
        }
        elseif ($forget)
        {
            Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -forget
        }
        else 
        {
            Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid  
        }
    }
}