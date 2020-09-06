Function Start-AGMLibWorkflow ([string]$workflowid,[string]$appid,[switch]$refresh,[switch][alias("g")]$guided)
{
    # if we don't get an appid, then lets presume we are going to build a command
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
            [int]$userselection = Read-Host "Please select an workflow to run (1-$listmax)"
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
        Write-Host "1`: Provision new virtual application (Default)"
        Write-Host "2`: Refresh existing application"
        Write-Host "3`: Exit without running the command"
        $userselection = Read-Host "Please select from this list (1-3)"
        if ($userselection -eq 2)
        {
            $refresh = $true
        }
        if ($userchoice -eq 3)
        {
            return
        }
    }

    if ($refresh)
    {
        $flowitemgrab = Get-AGMAPIData -endpoint /application/$appid/workflow/$workflowid
        if ($flowitemgrab.id.count -eq 1)
        {
            $flowitemid = $flowitemgrab.id
        }
        $frommoutgrab = Get-AGMAPIData -endpoint /application/$appid/workflow/$workflowid/frommount
        if ($frommoutgrab)
        {
            $mountedappid = $frommoutgrab.id
        }
    }

    $body = [ordered]@{}
    $body += @{ operation = "run"}
    if ($mountedappid)
    {
        $mountedapp = [ordered]@{ name = "app" ; value = $mountedappid }
        $items1 = @( $mountedapp )
        $items2 = @( [ordered]@{ name = "reprovision" ; items = $items1 } )
        $items3 = @( [ordered]@{ id = $flowitemid ; name = "mount" ; items = $items2 } )
        $update = [ordered]@{ id = $workflowid ; items = $items3 }
        $body += [ordered]@{ update = $update }
    }

    $json = $body | ConvertTo-Json -depth 8

    Post-AGMAPIData  -endpoint /application/$appid/workflow/$workflowid -body $json

}