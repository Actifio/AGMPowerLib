Function Get-AGMLibPolicies ([string]$appid,[string]$sltid) 
{
    <#
    .SYNOPSIS
    Get SLT policies

    .EXAMPLE
    Get-AGMLibPolicies

    .EXAMPLE
    Get-AGMLibAppPolicies -appid 2133445
    Get the policies for AppID 2133445

    .EXAMPLE
    Get-AGMLibAppPolicies  -sltid 2133445 
    Get the policies for SLT ID 2133445

    .DESCRIPTION
    A function to get policies

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
    
    $sltgrab = Get-AGMSLT | select-object id,name | sort-object name
    
    if ($sltgrab.id.count -eq 0)
    {
        Get-AGMErrorMessage -messagetoprint "Failed to find any SLTs"
        return
    }

    foreach ($slt in $sltgrab)
    {
        $policygrab = Get-AGMSLTpolicy -id $slt.id
        foreach ($policy in $policygrab)
        {
            write-host $slt.id $slt.name $policy.id $policy.name
        }
    }  
}