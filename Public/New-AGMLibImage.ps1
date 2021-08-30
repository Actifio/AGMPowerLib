Function New-AGMLibImage ([string]$appid,[string]$policyid,[string]$backuptype,[string]$capturetype,[string]$label,[switch][alias("m")]$monitor,[switch][alias("w")]$wait) 
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
    New-AGMLibImage -appid 2133445 -policyid 5678
    Create a new snapshot for AppID 2133445 using policyID 5678
    We learned the policy ID by using: Get-AGMLibPolicies -appid 2133445

    .EXAMPLE
    New-AGMLibImage  -appid 2133445 -label "Dev image after upgrade"
    Create a new snapshot for AppID 2133445 with a label.

    .EXAMPLE
    New-AGMLibImage  -appid 2133445 -backuptype log
    Create a new log snapshot for AppID 2133445


    .EXAMPLE
    New-AGMLibImage  -appid 2133445 -backuptype log -m 
    Create a new log snapshot for AppID 2133445 and monitor the resulting job to completion 


    .DESCRIPTION
    A function to create new snapshot images

    * Databases with log protection
    If a database has log protection, you will need to specify -backuptype 

    -backuptype log         This will run a log snapshot
    -backuptype db          This will run a DB snapshot

    * Monitoring options:

    -wait     This will wait up to 2 minutes for the job to start, checking every 15 seconds to show you the job name
    -monitor  Same as -wait but will also run Get-AGMLibFollowJobStatus to monitor the job to completion

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
    
    if ($capturetype)
    {
        $backuptype = $capturetype
    }


    if ($backuptype)
    {
        if (( $backuptype -ne "db") -and ( $backuptype -ne "log"))
        {
            Get-AGMErrorMessage -messagetoprint "Requested backuptype $backuptype is invalid, use either `'-backuptype db`' or `'-backuptype log`'"
            return
        }
    }
    if (!($backuptype))
    {
        $backuptype = ""
    }

    if (!($appid))
    {
        [string]$appid = Read-Host "AppID"
    }
    if ($policyid)
    {
        $policygrab = Get-AGMLibPolicies -appid $appid  | where-object { $_.id -eq $policyid }
        if ($policygrab.op.count -ne 1)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find policy ID $policyid for App ID $appid.  Please check the Policy ID and AppID with Get-AGMLibApplicationID and Get-AGMLibPolicies"
            return
        }
        $policyname = $policygrab.name

    }


    if (!($policyid))
    {     
        $jobclass = "snapshot"
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
            $policyname = $($policygrab | Where-Object {$_.op -eq "snap"} | Select-Object -last 1).name
            if (!($policyid))
            {
                Get-AGMErrorMessage -messagetoprint "Failed to learn Snap Policy ID for SLT ID $sltid"
                return
            }
        }
        # help the user
        write-host -nonewline  "Running this command: New-AGMLibImage  -appid $appid -policyid $policyid"
        if ($backuptype) 
        {
            write-host -nonewline " -backuptype $backuptype"
        }
        if ($label) 
        {
            write-host -nonewline " -label $label"
        }
        write-host ""
    }
    

    # now create JSON
    $policy = @{id=$policyid}
    $body = [ordered]@{}
    if ($label)
    {
        $body += @{label=$label}
    }
    $body += @{policy=$policy}
    if ($backuptype)
    {
        $body += @{backuptype=$backuptype}
    }
    $json = $body | ConvertTo-Json
    $runbackup = Post-AGMAPIData  -endpoint /application/$appid/backup -body $json
    if ($runbackup.err_message)
    {
        $runbackup
        return
    }
    if ($monitor)
    {
        $wait = $true
    }
    if ($wait)
    {
        Start-Sleep -s 2
        $i=1
        while ($i -lt 9)
        {
            Clear-Host
            write-host "Checking for an on-demand job with Policyname `'$policyname`' for appid $appid)"
            $jobgrab = Get-AGMJob -filtervalue "appid=$appid&policyname=$policyname&isscheduled=False" -sort queuedate:desc -limit 1 
            if (!($jobgrab.jobname))
            {
                write-host "Job not running yet, will wait 15 seconds and check again.   Check $i of 8"
                Start-Sleep -s 15
                $jobgrab = Get-AGMJob -filtervalue "appid=$appid&policyname=$policyname&isscheduled=False" -sort queuedate:desc -limit 1 
                if (!($jobgrab.jobname))
                {
                    $i++
                }
            }
            else
            {   
                $i=9
                if ($monitor)
                {
                    $jobgrab| select-object jobname,status,progress,queuedate,startdate,duration,targethost | ft *
                }
                else 
                {
                    $jobgrab| select-object jobname,status,progress,queuedate,startdate,targethost
                }
            }
        }
        if (($jobgrab.jobname) -and ($monitor))
        {
            Get-AGMLibFollowJobStatus $jobgrab.jobname
        }
    }
}