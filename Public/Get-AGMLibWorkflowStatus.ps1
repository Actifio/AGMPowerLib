Function Get-AGMLibWorkflowStatus ([string]$workflowid,[string]$appid,[switch][alias("m")]$monitor,[switch][alias("p")]$previous)
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
    Get-AGMLibWorkflowStatus -workflowid 1234 -monitor
    Monitors the status of workflow 1234 till completion

    .DESCRIPTION
    A function to monitor workflows

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
    
    # set datefields for later
    $datefields = "startdate,enddate"

    # without a workflow ID there is nothing to do, so lets ask.   if user supplied appid we get shorter list
    if (!($workflowid))
    {
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
        $flow | Add-Member -NotePropertyName friendlytype -NotePropertyValue $flow.application.friendlytype
        $flow | Add-Member -NotePropertyName appname -NotePropertyValue $flow.application.appname
        $flow | Add-Member -NotePropertyName appid -NotePropertyValue $flow.application.id
        $flow | Add-Member -NotePropertyName appliancename -NotePropertyValue $flow.cluster.name
        $flow | Add-Member -NotePropertyName frequency -NotePropertyValue $flow.schedule.frequency
        $i++
        }
        Clear-Host
        $workflowgrab | select-object select,name,workflowid,friendlytype,appname,appid,appliancename,frequency | Format-table *
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

    # if user asked for previous run the lets give that
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
        $durationgrab = NEW-TIMESPAN -start $jobgrab.startdate -end $jobgrab.enddate | select-object TotalMilliseconds
        $duration = Convert-AGMDuration ($durationgrab.TotalMilliseconds * 1000)
        $jobgrab | Add-Member -NotePropertyName duration  -NotePropertyValue $duration
        $jobgrab | select-object status,startdate,enddate,duration,result,jobtag
        # $jobgrab
        return
    }


    #if you user didn't ask to monitor then run once and exit
    if (!($monitor))
    {
        $jobgrab = (Get-AGMWorkFlow -filtervalue id=$workflowid).status.current
        foreach ($field in $datefields.Split(","))
        {
            if ($jobgrab.$field)
            {
                $jobgrab.$field = Convert-FromUnixDate $jobgrab.$field
            }
        }
        $jobgrab | select-object status,startdate,enddate,duration,result,jobtag
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
                if ($jobgrab.enddate.length -gt 0)
                {
                    $durationgrab = NEW-TIMESPAN -start $jobgrab.startdate -end $jobgrab.enddate | select-object TotalMilliseconds
                }
                else 
                {
                    $durationgrab = NEW-TIMESPAN -start $jobgrab.startdate -end (Get-date) | select-object TotalMilliseconds
                }
                
                $duration = Convert-AGMDuration ($durationgrab.TotalMilliseconds * 1000)
                $jobgrab | Add-Member -NotePropertyName duration  -NotePropertyValue $duration
                $jobgrab | select-object status,startdate,enddate,duration,result,jobtag
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
                $durationgrab = NEW-TIMESPAN -start $jobgrab.startdate -end (Get-date) | select-object TotalMilliseconds
                $duration = Convert-AGMDuration ($durationgrab.TotalMilliseconds * 1000)
                $jobgrab | Add-Member -NotePropertyName duration  -NotePropertyValue $duration
                $jobgrab | select-object status,startdate,enddate,duration,result,jobtag
                Start-Sleep -s 5  
            }
        } 
        until ($done -eq 1)    
    }
}