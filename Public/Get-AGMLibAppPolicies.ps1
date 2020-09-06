Function Get-AGMLibAppPolicies ([string]$appid) 
{
    <#
    .SYNOPSIS
    Get policy IDs for an app

    .EXAMPLE
    Get-AGMLibAppPolicies
    You will be prompted for Application ID

    .EXAMPLE
    Get-AGMLibAppPolicies 2133445
    Get the policies for AppID 2133445

    .EXAMPLE
    Get-AGMLibAppPolicies  -appid 2133445 
    Get the policies for AppID 2133445

    .DESCRIPTION
    A function to get the policies for a specified app

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

    if  (!($appid))
    {
        [string]$appid = Read-Host "AppID"
    }  

    $appgrab = Get-AGMApplication -filtervalue appid=$appid 
    
    $sltid = $appgrab.sla.slt.id
    if (!($sltid))
    {
        Get-AGMErrorMessage -messagetoprint "Failed to learn SLT ID for specified ID"
        return
    }
    else 
    {
    $policygrab = Get-AGMSltPolicy -id $sltid
    }
    if (!($policygrab))
    {
        Get-AGMErrorMessage -messagetoprint "Failed to learn Policies for SLT ID $sltid"
        return
    }
    else 
    {
        $policygrab
    }    
}