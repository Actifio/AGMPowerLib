Function Start-AGMLibWorkflow ([string]$workflowid,[string]$appid,[switch]$refresh,[switch][alias("m")]$monitor)
{
    <#
    .SYNOPSIS
    Starts a workflow

    .EXAMPLE
    Start-AGMLibWorkflow
    Runs a guided menu to let you start a workflow

    .EXAMPLE
    Start-AGMLibWorkflow -workflowid 1234
    Starts workflowflow id 1234 using the latest image

    .EXAMPLE
    Start-AGMLibWorkflow -workflowid 1234 -refresh
    Starts workflowflow id 1234 using the latest image refreshing an existing image

    .EXAMPLE
    Start-AGMLibWorkflow -workflowid 1234 -refresh -monitor
    Starts workflowflow id 1234 using the latest image refreshing an existing image, then monitors the workflow to completion

    .DESCRIPTION
    A function to start workflows

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
    if ( (!($appid)) -and ($workflowid) )
    {   
        $appid = (Get-AGMWorkFlow -filtervalue id=$workflowid).application.id
        if (!($appid))
        {
            Get-AGMErrorMessage -messagetoprint "Could not determine appid using workflow ID $workflowid."
            return
        }
    }


    # if we don't get an appid, then lets presume we are going to build a command
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
        $imagegrab = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot" -sort id:desc -limit 1 
        if ($imagegrab.id.count -eq 1)
        {
            $imageid = $imagegrab.srcid
            if ($imagegrab.endpit)
            {
                $endpit = $imagegrab.endpit
                $itemprops += @{ "key" = "recoverytime" ; "value" = $endpit }
            }
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find a snapshot for $appid"
            return
        }
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