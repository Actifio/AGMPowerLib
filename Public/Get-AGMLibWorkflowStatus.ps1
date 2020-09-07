Function Get-AGMLibWorkflowStatus ([string]$workflowid,[string]$appid,[switch]$refresh)
{
    # its pointless procededing without a connection.
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
    $datefields = "startdate,enddate"
    if ( (!($appid)) -or (!($workflowid)) )
    {
        $guided = $true
        Clear-Host
        Write-Host "Workflow selection menu"
        $workflowgrab = Get-AGMWorkFlow  | sort-object name
        if ($workflowgrab.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any workflows to list"
            return
        }
        Clear-Host
        write-host "Workflow selection menu - which Workflow will be run"
        Write-host ""
        $i = 1
        foreach ($flow in $workflowgrab)
        { 
            Write-Host -Object "$i`: Name: $($flow.name)  Workflow ID: $($flow.id)  AppName:  $($flow.application.appname) AppID:  $($flow.application.id)   Appliance: $($flow.cluster.name)  Schedule:   $($flow.schedule.frequency)"
            $i++
        }
        While ($true) 
        {
            Write-host ""
            $listmax = $workflowgrab.name.count
            [int]$userselection = Read-Host "Please select an workflow to check (1-$listmax)"
            if ($userselection -lt 1 -or $userselection -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
            } 
            else
            {
                break
            }
        }
        $appid = $workflowgrab.application.id[($userselection - 1)]
        $workflowid =  $workflowgrab.id[($userselection - 1)]
        write-host "Command to run is:  Get-AGMLibWorkflowStatus -appid $appid -workflowid $workflowid"
    }

    if (!($refresh))
    {
        (Get-AGMApplicationWorkflow  -id $appid | where-object {$_.id -eq $workflowid } | select-object status).status.current
    }
    else 
    {
        $done = 0
        do 
        {
            $jobgrab = (Get-AGMApplicationWorkflow  -id $appid | where-object {$_.id -eq $workflowid } | select-object status).status.current
            if ($jobgrab.status -ne "RUNNING")
            {   
                $done = 1
                $jobgrab = (Get-AGMApplicationWorkflow  -id $appid | where-object {$_.id -eq $workflowid } | select-object status).status.prev
                # time stamp conversion
                if ($datefields)
                {
                    foreach ($field in $datefields.Split(","))
                    {
                        if ($jobgrab.$field)
                        {
                            $jobgrab.$field = Convert-FromUnixDate $jobgrab.$field
                        }
                    }
                }
                $jobgrab
            }    
            else
            {
                # time stamp conversion
                if ($datefields)
                {
                    foreach ($field in $datefields.Split(","))
                    {
                        if ($jobgrab.$field)
                        {
                            $jobgrab.$field = Convert-FromUnixDate $jobgrab.$field
                        }
                    }
                }
                $jobgrab
                Start-Sleep -s 5  
            }
        } 
        until ($done -eq 1)    
    }
}