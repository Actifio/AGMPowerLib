Function New-AGMLibGCEInstance ([string]$imageid,[string]$project,[string]$imagename,[string]$credentialid,[string]$zone,[string]$instancename,[string]$machinetype,[string]$serviceaccount,[string]$bootdisk,[string]$poweroffvm) 
{
    <#
    .SYNOPSIS
    Mounts a PD Snapshot as a new GCE Instance
    Get-AGMApplication -filtervalue "apptype=GCPInstance&managed=True" 


    .EXAMPLE
    New-AGMLibGCEInstance -imageid 56410933 -credentialid 4447 -project testp2 -instancename avtest21 -machinetype e2-micro

    This mounts the specified imageid

    .DESCRIPTION
    A function to create a new GCE Instance from a PD Snapshot


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

    # learn about the image
    if (($imagename) -and (!($imageid)))
    {
        $imagecheck = Get-AGMImage -filtervalue backupname=$imagename
        if (!($imagecheck))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imagename using:  Get-AGMImage -filtervalue backupname=$imagename"
            return
        }
        else 
        {
            $imagegrab = Get-AGMImage -id $imagecheck.id
            $imageid = $imagegrab.id
        }
    }
    if (($imageid) -and (!($imagename)))
    {
        $imagecheck = Get-AGMImage -id $imageid
        if (!($imagecheck))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imageid using:  Get-AGMImage -id $imageid"
            return
        }
        else 
        {
            $imagename = $imagegrab.backupname
        }
    }
    if ((!($imagename)) -and (!($imageid)))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify either -imageid or -imagename"
        return
    }

    if (!($credentialid))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a credential ID for the new instance with -credentialid"
        return
    }
    if (!($project))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a project for the new instance with -project"
        return
    }
    if (!($zone))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a zone for the new instance with -zone"
        return
    }
    if (!($instancename))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a name for the new instance with -instancename"
        return
    }
    if (!($machinetype))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a machinetype for the new instance with -machinetype"
        return
    }

    
        
    Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json
    
    
}