Function Get-AGMLibSLA  ([string]$appid,[string]$slaid,[string]$logicalgroupid)
{
    <#
    .SYNOPSIS
    Get the enable status of SLAs for scheduler and expiration. 

    .EXAMPLE
    Get-AGMLibSLA
    To check on all managed apps

    .EXAMPLE
    Get-AGMLibSLA -appid 1234
    To check on app ID 1234

    .EXAMPLE
    Get-AGMLibSLA -slaid 5678
    To check on sla ID 5678

    .EXAMPLE
    Get-AGMLibSLA logicalgroupid 5678
    To check on all apps in logical group ID 5678

    .DESCRIPTION
    A function to check enable or disable status of each SLA
    You can change the status with Set-AGMLibSLA

    #>


    # its pointless procededing without a connection.
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
    
    if ($slaid)
    {
        $slagrab = Get-AGMSLA -filtervalue id=$slaid
        if ($slagrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "No SLAa were found using slaid $slaid"
            return
        }
    }
    elseif ($appid)
    {
        $slagrab = Get-AGMSLA -filtervalue appid=$appid
        if ($slagrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "No SLAs were found using appid $appid"
            return
        }
    }
    else {
        $slagrab = Get-AGMSLA
    }
    
    if ($appid)
    {
        $applicationgrab = Get-AGMApplication -filtervalue id=$appid
    }
    elseif ($logicalgroupid) {
        $applicationgrab = Get-AGMApplication -filtervalue inlogicalgroupof=$logicalgroupid
    } else
    {
        $applicationgrab = Get-AGMApplication
    }


    $printarray = @()
    foreach ($sla in $slagrab)
    {
        if ($sla.expirationoff -eq "true") { $expiration = "disabled" } else { $expiration = "enabled" }
        if ($sla.scheduleoff -eq "true") { $scheduler = "disabled" } else { $scheduler = "enabled" } 
        $hostname = ($applicationgrab |  where-object {$_.id -eq $sla.application.id}).host.hostname  
        $sla | Add-Member -NotePropertyName hostname -NotePropertyValue $hostname    
        $appname = ($applicationgrab |  where-object {$_.id -eq $sla.application.id} | select-object appname).appname
        $groupname = ($applicationgrab |  where-object {$_.id -eq $sla.application.id} | select-object logicalgroup).logicalgroup.name
        $groupid = ($applicationgrab |  where-object {$_.id -eq $sla.application.id} | select-object logicalgroup).logicalgroup.id
        $sla | Add-Member -NotePropertyName appname -NotePropertyValue $appname
        if ($logicalgroupid)
        {
            if ($appname.length -gt 0)
            {
                $printarray += [pscustomobject]@{
                    hostname = $sla.hostname
                    appname = $sla.appname
                    apptype = $sla.application.apptype
                    slaid = $sla.id
                    appid = $sla.application.id
                    scheduler = $scheduler
                    expiration = $expiration
                    sltname = $sla.slt.name
                    slpname = $sla.slp.name
                    logicalgroupname = $groupname
                    logicalgroupid = $groupid
                }
            }
        } 
        else 
        {
            $printarray += [pscustomobject]@{
                hostname = $sla.hostname
                appname = $sla.appname
                apptype = $sla.application.apptype
                slaid = $sla.id
                appid = $sla.application.id
                scheduler = $scheduler
                expiration = $expiration
                sltname = $sla.slt.name
                slpname = $sla.slp.name
                logicalgroupname = $groupname
                logicalgroupid = $groupid
            }
        }

    }
    $printarray  | sort-object hostname,appname | Format-Table
}
