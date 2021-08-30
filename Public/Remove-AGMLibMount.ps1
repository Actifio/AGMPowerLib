function Remove-AGMLibMount([string]$label,[string]$imagename,[string]$imageid,[switch][alias("d")]$delete,[switch][alias("p")]$preservevm,[switch][alias("f")]$force)
{
    <#
    .SYNOPSIS
    Unmounts a nominated image or images

    .EXAMPLE
    Remove-AGMLibMount
    You will be prompted for image Name 

    .EXAMPLE
    Remove-AGMLibMount -imagename Image_2133445
    Unmounts Image_2133445 but does not delete it

    .EXAMPLE
    Remove-AGMLibMount -imagename Image_2133445 -d
    Unmounts Image_2133445 and deletes it from Actifio and from the cloud if a mount is a GCP VM created from Persistent Disk Snapshot

    .EXAMPLE
    Remove-AGMLibMount -imagename Image_2133445 -p
    For Google Cloud Persistent Disk (PD) mounts
    Unmounts Image_2133445 and deletes it on Actifio Side but preserves it on Google side.

    .DESCRIPTION
    A function to unmount images

    -delete (-d)      Is used to unmount and delete an image.  If not specified then an unmount is done, but the image is retained on the Actifio Side
    -force (-f)       Removes the mount even if the host-side command to remove the mounted application fails.   This can leave artifacts on the Host and should be used with caution
    -preservevm (-p)  This applies to GCE Instances created from PD Snapshot.   When used the Actifio Image of the mount is removed, but on the GCP side the new VM is retained.   

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    $sessiontest = Get-AGMVersion
    if (!($sessiontest.summary))
    {
        Get-AGMErrorMessage -messagetoprint "AGM session has expired. Please login again using Connect-AGM"
        return
    }

    if ((!($imagename)) -and (!($label)) -and (!($imageid)))
    {
        Clear-Host
        Write-Host "This function is designed to assist you removing mounted images."
        Write-Host "We do this by selecting an image or a range of images using their label"
        Read-Host -Prompt "Press enter to display the current mounts"
        Clear-Host
        $mountgrab = Get-AGMLibActiveImage 
        if (!($mountgrab.imagename))
        {
            write-host "here"
            $mountgrab
            return
        }
        if ($mountgrab.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any mounted images with Get-AGMLibActiveImage"
            return
        }
        
        $printarray = @()
        $i = 1
        foreach ($mount in $mountgrab)
        {
            $printarray += [pscustomobject]@{
                id = $i
                imageid = $mount.id
                imagename = $mount.imagename
                apptype = $mount.apptype
                hostname = $mount.hostname
                appname = $mount.appname
                mountedhost = $mount.mountedhost
                imagestate = $mount.imagestate
                label = $mount.label
            }
            $i += 1
        }
        $printarray | format-table
       
        if ($printarray.imageid.count -eq 1)
        {
            write-host ""
            Write-host "Only one image found, this is the one we will work with"
            $imageid = $printarray.imageid
            $apptype = $printarray.apptype
            $imagestate = $printarray.imagestate
            $imagename = $printarray.imagename
        }
        else 
        {
            write-host ""
            Write-host "Unmount selection method:"
            Write-Host "a`: Select one image by ImageName (default)"
            Write-Host "b`: Select a label"
        
            While ($true) 
            {
                $userchoice = Read-Host "Please select from this list (a or b)"
                if ($userchoice -ne "a" -and $userchoice -ne "b")
                {
                    Write-Host -Object "Invalid selection. Please enter either a or b"
                } 
                else
                {
                    break
                }
            }
            if ($userchoice -eq "a") 
            {        
                While ($true) 
                {
                    $listmax = $printarray.imageid.count
                    [int]$userselection1 = Read-Host "Please select the ID of one image in the list.  This image will be unmounted (1-$listmax)"
                    if ($userselection1 -lt 1 -or $userselection1 -gt $listmax)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
                    } 
                    else
                    {
                        break
                    }
                }
                $imageid = $printarray.imageid[($userselection1 - 1)]
                $apptype = $printarray.apptype[($userselection1 - 1)]
                $imagestate = $printarray.imagestate[($userselection1 - 1)]
                $imagename = $printarray.imagename[($userselection1 - 1)]
            }
            
            if ($userchoice -eq "b") 
            { 
                While ($true) 
                {
                    $listmax = $printarray.count
                    [int]$userselection2 = Read-Host "Please select the ID of one image in the list.  All images with the matching label will be unmounted(1-$listmax)"
                    if ($userselection2 -lt 1 -or $userselection2 -gt $listmax)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
                    } 
                    else
                    {
                        break
                    }
                }
                $label = $printarray.label[($userselection2 - 1)]        
            }
        }
        Write-Host ""
        Write-host "Delete setting"
        Write-Host "1`: Unmount only (default)"
        Write-Host "2`: Unmount and delete"
        [int]$userchoice = Read-Host "Please select from this list (1-2)"
        if ($userchoice -eq 2) { $delete = $true }
        write-host ""
        Write-host "Force setting"
        Write-Host "1`: Do not force the unmount if host side commands do not release the disk (default)"
        Write-Host "2`: Force the unmount"
        [int]$userchoice = Read-Host "Please select from this list (1-2)"
        if ($userchoice -eq 2) { $force = $true }
        if (($apptype -eq "GCPInstance") -or ($label))
        {
            write-host ""
            Write-host "Preserve VM setting"
            Write-Host "1`: Delete the VM on both the GCP side and the Actifio Side (default)"
            Write-Host "2`: Preserve the VM on the GCP side"
            [int]$userchoice = Read-Host "Please select from this list (1-2)"
            if ($userchoice -eq 2) { $preservevm = $true }
        }
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline "Remove-AGMLibMount"
        if ($imagename) { write-host -nonewline " -imagename $imagename" }
        if ($label) { write-host -nonewline " -label `"$label`"" }
        if ($delete) { write-host -nonewline " -delete" }
        if ($force) { write-host -nonewline " -force" }
        if ($preservevm) { write-host -nonewline " -preservevm" }
        Write-Host ""
        Write-Host "1`: Run the command now and exit (default)"
        Write-Host "2`: Exit without running the command"
        $everyuserchoice = Read-Host "Please select from this list (1-2)"
        if ($everyuserchoice -eq 2)
        {
            return
        }
    }
    if ($imageid)
    {
        $id = $imageid
    }
    if ($imagename)
    {
        $imagegrab = Get-AGMLibActiveImage | where-object {$_.imagename -eq $imagename}
        if ($imagegrab.id)
        {
            $id = $imagegrab.id
            $imagestate = $imagegrab.imagestate
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imagename"
            return
        }
    }

    if ($delete)
    { 
        $deleterequest="true"
    }
    else 
    {
        $deleterequest="false"
    }
    if ($force)
    { 
        $forcerequest="true"
    }
    else 
    {
        $forcerequest="false"
    }
    if ($preservevm)
    { 
        $preservevmrequest="true"
    }
    else 
    {
        $preservevmrequest="false"
    }

    if ($label)
    {
        $mountlist = Get-AGMLibActiveImage | where-object  {$_.label -eq "$label"}
        foreach ($mount in $mountlist)
        {
            $id = $mount.id
            $body = @{delete=$deleterequest;force=$forcerequest;preservevm=$preservevmrequest}
            $json = $body | ConvertTo-Json
            if ($mount.imagestate -ne "Unmounted")
            {   
                Post-AGMAPIData -endpoint /backup/$id/unmount -body $json
            }
            else 
            {
                Remove-AGMImage -imageid $id
            }
        }
    }
    else 
    {
        $body = @{delete=$deleterequest;force=$forcerequest;preservevm=$preservevmrequest}
        $json = $body | ConvertTo-Json
        if ($imagestate -ne "Unmounted")
        {        
        
            Post-AGMAPIData -endpoint /backup/$id/unmount -body $json    
        }
        else 
        {
            Remove-AGMImage -imagename $imagename
        }
    }
}