Function Start-AGMLibWorkflow ([string]$workflowid,[string]$appid,[string]$imagename,[string]$recoverypoint,[switch]$refresh,[switch][alias("m")]$monitor)
{
    <#
    .SYNOPSIS
    Starts a workflow

    .EXAMPLE
    Start-AGMLibWorkflow
    Runs a guided menu to let you start a workflow

    .EXAMPLE
    Start-AGMLibWorkflow -workflowid 29409450 -appid 56430632 
    
    Starts workflow id 29409450 for appid 56430632 using the latest image.    If the appname already exists the workflow will fail.   You need to add -refresh
    Because no image was specified, if there are logs the mount will be rolled to the latest point in time.
    Note that the appid parameter is not mandatory but specifying it will make the function run slightly faster

    .EXAMPLE
    Start-AGMLibWorkflow -workflowid 29409450 -appid 56430632 -refresh
    
    Starts workflow id 29409450 for appid 56430632 refreshing an existing mount.  Note that if no mount exists a new one will be created.

    .EXAMPLE
    Start-AGMLibWorkflow -workflowid 29409450 -appid 56430632 -imagename Image_29363841 -m -refresh
    
    Starts workflow id 29409450 for appid 56430632 refreshing an existing mount using the specified image, then monitors the workflow to completion
    Because an image was specified but a recoverypoint was not, no roll log roll forward will be run.  

    .EXAMPLE
    Start-AGMLibWorkflow -workflowid 29409450 -appid 56430632 -imagename Image_29411948 -recoverypoint "2020-11-12 21:48:39" -m -refresh
    
    Starts workflow id 29409450 for appid 56430632 refreshing an existing mount using the specified image and recovery point, then monitors the workflow to completion.
    The recovery point must be specified in host time, not user time.  This is important if the user (local) timezone is different to the host timezone.
    AGMPowerCLI default is to always show all time and date fields included ENDPIT in user (local) timezone.

    .DESCRIPTION
    A function to start workflows

    -workflowid     Mandatory, needed to identify the workflow.  Learn this by running this function without specifying anything.
    -appid          Not mandatory, but helpful.  Learn this by running this function without specifying anything.
    -imagename      Not mandatory.  If not specified, the latest snapshot image will be used
    -recoverypoint  Not mandatory.  Must be used with an imagename.  Must be in ISO format like 2020-10-10 10:10:10  Must be host time
    -refresh        Refreshes an existing mount.   If a mount does not exist, a new one will be created.   Not mandatory, but if an existing mount exists, you must either unmount it, or specify refresh.  
    -monitor        Monitors the workflow to completion

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

    # if we get a workflow ID, lets learn the AppID.   We need AppID as part of the API
    if ( (!($appid)) -and ($workflowid) )
    {   
        $appid = (Get-AGMWorkFlow -filtervalue id=$workflowid).application.id
        if (!($appid))
        {
            Get-AGMErrorMessage -messagetoprint "Could not determine appid using workflow ID $workflowid."
            return
        }
    }


    # if we don't get an appid or workflow ID, then we are going to need to build a command guided style
    if ( (!($appid)) -or (!($workflowid)) )
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
        write-host "Workflow selection menu - which Workflow will be run"
        Write-host ""
        $workflowgrab | select-object select,name,workflowid,friendlytype,appname,appid,appliancename,frequency | Format-table *
        While ($true) 
        {
            Write-host ""
            $listmax = $workflowgrab.name.count
            [int]$userselection = Read-Host "Please select a workflow to run (1-$listmax)"
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
        $workflowname =  $workflowgrab.name[($userselection - 1)]

        write-host "Selected $workflowid $workflowname for Appid $appid"
        Write-Host ""
        Write-Host "1`: Provision new virtual application (Default).     This command will be run:  Start-AGMLibWorkflow -workflowid $workflowid -appid $appid"
        Write-Host "2`: Refresh existing application.     This command will be run:  Start-AGMLibWorkflow -workflowid $workflowid -appid $appid -refresh"
        Write-Host "3`: Exit without running the command"
        $userselection = Read-Host "Please select from this list (1-3)"
        if ($userselection -eq 2)
        {
            $refresh = $true
        }
        if ($userselection -eq 3)
        {
            return
        }
    }
    

    # if we run a refresh we need to send some flow info.   In GUI, user could change this, but for now we are going to use the saved info.
    if ($refresh)
    {
        $flowitemgrab = Get-AGMApplicationWorkflowStatus -id $appid -workflowid $workflowid 
        # $flowitemgrab = Get-AGMAPIData -endpoint /application/$appid/workflow/$workflowid -itemoverride
        if ($flowitemgrab.id.count -eq 1)
        {
            $flowitemid = $flowitemgrab.id
            $schedule = $flowitemgrab.schedule
            $cluster = $flowitemgrab.cluster
            $propgrab = $flowitemgrab.props
            $itemprops = $flowitemgrab.items.props
            $itemgrab = $flowitemgrab.items.items
        }
        $frommoutgrab = Get-AGMAPIData -endpoint /application/$appid/workflow/$workflowid/frommount
        if ($frommoutgrab)
        {
            $mountedappid = $frommoutgrab.id
        }
        if (!($imagename))
        {
            $imagegrab = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot" -sort id:desc -limit 1 
            if ($imagegrab.id.count -eq 1)
            {
                $imageid = $imagegrab.srcid
                if (!($recoverypoint))
                {
                    if ($imagegrab.endpit)
                    {
                        if ($usertimezone)
                        {
                            $endpit = $imagegrab.endpit
                            $itemprops += @{ "key" = "recoverytime" ; "value" = $endpit }
                        }
                        else 
                        {
                            $oldagmtz = $AGMTimezone
                            Set-AGMTimeZoneHandling -u
                            $imagegrab2 = Get-AGMImage ($imagegrab).id
                            [datetime]$endpitutc = $imagegrab2.endpit
                            $hosttimezone = $imagegrab2.hosttimezone
                            $HoursToAdd = $hosttimezone.substring(3,3)
                            $MinutesToAdd = $hosttimezone.substring(6,2)
                            $endpit = $endpitutc.AddHours($HoursToAdd).AddMinutes($MinutesToAdd).ToString('yyyy-MM-dd HH:mm:ss')
                            $itemprops += @{ "key" = "recoverytime" ; "value" = $endpit }
                            if ($oldagmtz -eq "local")
                            {
                                Set-AGMTimeZoneHandling -l
                            }
                        }
                    }
                }
            }
            else 
            {
                Get-AGMErrorMessage -messagetoprint "Failed to find a snapshot for $appid"
                return
            }
        }
    }

    # if user supplied an image name, we are going to learn the SRC ID since we need this.   We are NOT going to learn the ENDPIT, if the user wants recovery time, they can define that, else we wont roll forward.  
    if ($imagename)
    {
        $imagegrab = Get-AGMImage -filtervalue "backupname=$imagename" -sort id:desc -limit 1 
        if ($imagegrab.id.count -eq 1)
        {
            $imageid = $imagegrab.srcid
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find a snapshot for $appid"
            return
        }
    }

    # if user supplied a recovery point we will use it without checking it.   
    if ($recoverypoint)
    {
        $itemprops += @{ "key" = "recoverytime" ; "value" = $recoverypoint }
    }

    $body = [ordered]@{}
    $body += @{ operation = "run"}
    if ($mountedappid)
    {
        $inneritems = @( $itemgrab )
        $inneritems += @( [ordered]@{ name = "reprovision" ; items = @( [ordered]@{ name = "app" ; value = $mountedappid } ) } )
        $flowgrabitems = @( [ordered]@{ id = $flowitemid ; name = "mount" ; props = $itemprops ; items = $inneritems } )
        $props = @( [ordered]@{ key = "image" ; value = $imageid } )
        $props += @( $propgrab )
        $update = [ordered]@{ id = $workflowid ; name = "" ; schedule = $schedule ; props = $props ; items = $flowgrabitems ; cluster = $cluster }
        $body += [ordered]@{ update = $update }
    }

    $json = $body | ConvertTo-Json -depth 10

    Post-AGMAPIData  -endpoint /application/$appid/workflow/$workflowid -body $json
    if ($monitor)
    {
        Get-AGMLibWorkflowStatus -workflowid $workflowid -monitor
    }

}