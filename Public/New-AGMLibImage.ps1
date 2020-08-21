Function New-AGMLibImage ([int]$appid,[int]$policyid,[string]$capturetype,[switch][alias("m")]$monitor) 
{
    <#
    .SYNOPSIS
    Creates a new image 

    .EXAMPLE
    New-AGMLibImage 
    You will be prompted for Application ID

    .EXAMPLE
    New-AGMLibImage  2133445
    Create a new snapshot for AppID 2133445

    .EXAMPLE
    New-AGMLibImage  -appid 2133445 -capturetype log
    Create a new log snapshot for AppID 2133445


    .EXAMPLE
    New-AGMLibImage  -appid 2133445 -capturetype log -m 
    Create a new log snapshot for AppID 2133445 and monitor the resulting job to completion 


    .DESCRIPTION
    A function to create new snapshot images

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

    if ($capturetype)
    {
        if (( $capturetype -ne "db") -and ( $capturetype -ne "log"))
        {
            Get-AGMErrorMessage -messagetoprint "Requested backup type is invalid, use either db or log"
            return
        }
    }
    if (!($capturetype))
    {
        $capturetype = "db"
    }

    if (!($appid))
    {
        [int]$appid = Read-Host "AppID"
    }
    if (!($policyid))
    {     
        $appgrab = Get-AGMApplication -filtervalue appid=$appid 
        $sltid = $appgrab.sla.slt.id
        if (!($sltid))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to learn SLT ID for App ID $appid"
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
            $policyid = $($policygrab | Where-Object {$_.op -eq "snap"} | Select-Object -last 1).id
            if (!($policyid))
            {
                Get-AGMErrorMessage -messagetoprint "Failed to learn Snap Policy ID for SLT ID $sltid"
                return
            }
        }
        $policy = @{id=$policyid}
        $body = @{policy=$policy;backuptype=$capturetype}
        $json = $body | ConvertTo-Json
        Post-AGMAPIData  -endpoint /application/$appid/backup -body $json
        Start-Sleep -s 5
        $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=1&isscheduled=false" -sort queuedate:desc -limit 1 | select-object jobname,status,queuedate,startdate
        if (($jobgrab) -and ($monitor))
        {
            Get-AGMFollowJobStatus $jobgrab.jobname
        }
        else 
        {
            $jobgrab 
        }
    }
}