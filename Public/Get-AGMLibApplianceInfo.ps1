Function Get-AGMLibApplianceInfo([string]$skyid,[string]$request,[string]$params) 
{
    <#
    .SYNOPSIS
    Fetches output of info API commands from appliances

    .EXAMPLE
    Get-AGMLibApplianceInfo -skyid -request "getparameter"
    Displays all active images (mounts)

    .EXAMPLE
    Get-AGMActiveImages
    Displays all active images (mounts)

    .EXAMPLE
    Get-AGMActiveImages -appid 4771
    Displays all active images for the app with ID 4771

    .DESCRIPTION
    A function to find the active images

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
    
 
}