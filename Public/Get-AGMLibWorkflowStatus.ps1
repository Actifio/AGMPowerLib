Function Get-AGMLibWorkflowStatus ([string]$workflowid,[string]$appid,[switch]$refresh,[switch][alias("p")]$previous)
{
    <#
    .SYNOPSIS
    Monitors a workflow

    .EXAMPLE
    Get-AGMLibWorkflowStatus
    Runs a guided menu to let you select a workflow

    .EXAMPLE
    Get-AGMLibWorkflowStatus -workflowid 1234
    Gets the current status of workflow 1234

    .EXAMPLE
    Get-AGMLibWorkflowStatus -workflowid 1234 -prev
    Gets the previous status of workflow 1234

    .EXAMPLE
    Get-AGMLibWorkflowStatus -workflowid 1234 -refresh
    Gets the current status of workflow 1234 and monitors it till completion

    .DESCRIPTION
    A function to monitor workflows

    #>


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
    if (!($workflowid))
    {
        Clear-Host
        Write-Host "Workflow selection menu"
        if ($appid)
        {
            $workflowgrab = Get-AGMWorkFlow -filtervalue appid=$appid  | sort-object name
        }
        else 
        {
            $workflowgrab = Get-AGMWorkFlow  | sort-object name
        }
        if ($workflowgrab.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any workflows to list"
            return
        }
        Clear-Host
        write-host "Workflow selection menu - which Workflow will be checked"
        Write-host ""
        $i = 1
        foreach ($flow in $workflowgrab)
        { 
        $flow | Add-Member -NotePropertyName select -NotePropertyValue $i
        $flow | Add-Member -NotePropertyName workflowid -NotePropertyValue $flow.id
        $flow | Add-Member -NotePropertyName appname -NotePropertyValue $flow.application.appname
        $flow | Add-Member -NotePropertyName appid -NotePropertyValue $flow.application.id
        $flow | Add-Member -NotePropertyName appliancename -NotePropertyValue $flow.cluster.name
        $flow | Add-Member -NotePropertyName frequency -NotePropertyValue $flow.schedule.frequency
        $i++
        }
        Clear-Host
        write-host "Workflow selection menu - which Workflow will be run"
        Write-host ""
        $workflowgrab | select-object select,name,workflowid,appname,appid,appliancename,frequency | Format-table *
        While ($true) 
        {
            Write-host ""
            $listmax = $workflowgrab.name.count
            [int]$userselection = Read-Host "Please select a workflow to check (1-$listmax)"
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
        if ($prev)
        {
            write-host "Command to run is:  Get-AGMLibWorkflowStatus -workflowid $workflowid -prev"
        }
        else 
        {
            write-host "Command to run is:  Get-AGMLibWorkflowStatus -workflowid $workflowid"
        }

    }

    if ($previous)
    {
        $jobgrab = (Get-AGMWorkFlow -filtervalue id=$workflowid).status.prev
        foreach ($field in $datefields.Split(","))
        {
            if ($jobgrab.$field)
            {
                $jobgrab.$field = Convert-FromUnixDate $jobgrab.$field
            }
        }
        $jobgrab
        return
    }



    if (!($refresh))
    {
        (Get-AGMWorkFlow -filtervalue id=$workflowid).status.current
    }
    else 
    {
        $done = 0
        do 
        {
            $jobgrab = (Get-AGMWorkFlow -filtervalue id=$workflowid).status.current
            if ($jobgrab.status -ne "RUNNING")
            {   
                $done = 1
                $jobgrab = (Get-AGMWorkFlow -filtervalue id=$workflowid).status.prev
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