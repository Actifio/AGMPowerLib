Function Get-AGMLibPolicies ([string]$appid,[string]$sltid) 
{
    <#
    .SYNOPSIS
    Get SLT policies

    .EXAMPLE
    Get-AGMLibPolicies

    .EXAMPLE
    Get-AGMLibPolicies -appid 2133445
    Get the policies for AppID 2133445

    .EXAMPLE
    Get-AGMLibPolicies -sltid 2133445 
    Get the policies for SLT ID 2133445

    .DESCRIPTION
    A function to get policies

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



    if ($sltid)
    {
        $sltgrab = Get-AGMSLT -id $sltid | select-object id,name | sort-object name
    }
    if ($appid)
    {
        $appgrab = Get-AGMApplication -filtervalue appid=$appid 
        $sltid = $appgrab.sla.slt.id
        if ($sltid.length -gt 0)
        {
            $sltgrab = Get-AGMSLT -id $sltid | select-object id,name | sort-object name
        }
    }
    if ( (!($appid)) -and (!($sltid)) )
    {
        $sltgrab = Get-AGMSLT | select-object id,name | sort-object name
    }
    
    
    if (($sltgrab.id.count -eq 0) -and ($appid))
    {
        Get-AGMErrorMessage -messagetoprint "Failed to find any SLTs for Appid $appid"
        return
    }
    elseif (($sltgrab.id.count -eq 0) -and ($sltid))
    {
        Get-AGMErrorMessage -messagetoprint "Failed to find any SLTs for SLT ID $sltid"
        return
    }
    elseif ($sltgrab.id.count -eq 0)
    {
        Get-AGMErrorMessage -messagetoprint "Failed to find any SLTs"
        return
    }

    foreach ($slt in $sltgrab)
    {
        $policygrab = Get-AGMSLTpolicy -id $slt.id
        foreach ($policy in $policygrab)
        {
            if ($policy.op -eq "snap") { $operation = "snapshot" }
            elseif ($policy.op -eq "cloud")
            { $operation = "onvault" }
            else {
                $operation = $policy.op
            }  
            $policy | Add-Member -NotePropertyName operation -NotePropertyValue $operation
            $policy | Add-Member -NotePropertyName policyid -NotePropertyValue $policy.id
            $policy | Add-Member -NotePropertyName sltid -NotePropertyValue $slt.id 
            $policy | Add-Member -NotePropertyName sltname -NotePropertyValue $slt.name
            if ($policy.retention)
            {
                $policy.retention = $policy.retention + " " + $policy.retentionm
            }
            if ($policy.rpo)
            {
                $policy.rpo = $policy.rpo + " " + $policy.rpom
            }
            if ($policy.starttime)
            {
                $st = [timespan]::fromseconds($policy.starttime)
                $policy.starttime = $st.ToString("hh\:mm")
            }
            if ($policy.endtime)
            {
                $et = [timespan]::fromseconds($policy.endtime)
                $policy.endtime = $et.ToString("hh\:mm")
            }
        }
        $policygrab | select-object sltid,sltname,policyid,name,operation,priority,retention,starttime,endtime,rpo
    }  
}
