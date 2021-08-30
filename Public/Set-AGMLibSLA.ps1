Function Set-AGMLibSLA ([string]$appid,[string]$slaid,[string]$logicalgroupid,[string]$expiration,[string]$scheduler,[switch][alias("e")]$everysla,[switch][alias("s")]$showsla) 
{
    <#
    .SYNOPSIS
    Enables or disables an SLA 
    Note that if both an SLA ID and an App ID are supplied, the App ID will be ignored.

    .EXAMPLE
    Set-AGMLibSLA
    Run a guided wizard

    .EXAMPLE
    Set-AGMLibSLA -logicalgroupid 99214  -scheduler enable -expiration enable
    Enabled the scheduler and expiration for all apps in one logical group

    .EXAMPLE
    Set-AGMLibSLA -everysla -scheduler disable -expiration disable
    Disable every SLA for both scheduler and expiration.   Use with caution!

    .DESCRIPTION
    A function to enable or disable the scheduler or expiration

    #>


    # its pointless procededing without a connection.
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

    if ($id)
    {
        $slaid = $id
    }

    if (($appid) -and (!($slaid)))
    {
        $slaid = (Get-AGMSLA -filtervalue appid=$appid).id
        if (!($slaid))
        {
            Get-AGMErrorMessage -messagetoprint "Could not find an SLA ID for App ID $appid   Please use Get-AGMSLA to find the correct SLA ID or Get-AGMApplication to find the correct App ID"
            return
        }
    }

    if ($logicalgroupid)
    {
        $logicalgroupgrab = (Get-AGMLogicalGroup $logicalgroupid).sla
        if (!($logicalgroupgrab))
        {
            Get-AGMErrorMessage -messagetoprint "Could not find any SLA ID for Logical Group ID $logicalgroupid   Please use Get-AGMLogicalGroup to find the correct managed Group ID"
            return
        }
    }

    if ( (!($slaid)) -and (!($logicalgroupid)) -and (!($everysla)))
    {
        #guided mode
        write-host ""
        Write-Host "This command is used to enable or disable the scheduler and/or expiration."
        Write-Host "This is either for a specific application, a specific logical group or every application"
        write-host ""
        Write-Host "1`: Lets get started (default)"
        Write-Host "2`: I need to know the current state - please run Get-AGMLibSLA"
        $userchoice = Read-Host "Please select from this list (1-2)"
        if ($userchoice -eq 2)
        {
            $slagrab = Get-AGMLibSLA
            $slagrab
            Read-Host -Prompt "Press enter to continue"
        }
        write-host ""
        Write-Host "Step one: What change do you want to make to the scheduler state (we will determine which apps are affected by this in step 3)"
        Write-Host "1`: I don't want to change the scheduler (default)"
        Write-Host "2`: I want to enable the scheduler"
        Write-Host "3`: I want to disable the scheduler"
        $userchoice = Read-Host "Please select from this list (1-3)"
        if ($userchoice -eq 3)
        {
            $scheduler = "disable"
        }
        if ($userchoice -eq 2)
        {
            $scheduler = "enable"
        }
        write-host ""
        Write-Host "Step two: What change do you want to make to the Expiration state"
        Write-Host "1`: I don't want to change expiration (default)"
        Write-Host "2`: I want to enable expiration"
        Write-Host "3`: I want to disable expiration"
        $userchoice = Read-Host "Please select from this list (1-3)"
        if ($userchoice -eq 3)
        {
            $expiration = "disable"
        }
        if ($userchoice -eq 2)
        {
            $expiration = "enable"
        }
        $command = ""; if ($scheduler) { $command += " -scheduler $scheduler" }; if ($expiration) { $command += " -expiration $expiration" }
        Write-Host ""
        Write-Host "Step 3: What do you want to work with?"
        Write-Host "1`: I want to work with one application (default)"
        Write-Host "2`: I want to work with one logical group"
        Write-Host "3`: I want to work with every application known to AGM"
        $userchoice = Read-Host "Please select from this list (1-3)"
        if ($userchoice -eq "") { $userchoice = 1 }
        if ($userchoice -eq 1)
        {
            $appgrab = Get-AGMApplication -sort "hostname:asc,appname:asc" | where-object {$_.sla.length -gt 0} 

            $printarray = @()
            $i = 1
            foreach ($app in $appgrab)
            {
                $printarray += [pscustomobject]@{
                    id = $i
                    apptype = $app.apptype
                    hostname = $app.host.hostname
                    appname = $app.appname
                    appid = $app.id
                    slaid = $app.sla.id
                }
                $i += 1
            }

            $printarray | Format-Table

            While ($true) 
            {
                Write-host ""
                $listmax = $printarray.appid.count
                [int]$userselection = Read-Host "Please select an ID to run (1-$listmax)"
                if ($userselection -lt 1 -or $userselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $slaid = $printarray.slaid[($userselection - 1)]
            
            Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
            Write-Host ""
            Write-Host "Set-AGMLibSLA -slaid $slaid $command"
            Write-Host ""
            Write-Host "1`: Run the command now (default)"
            Write-Host "2`: Run the command now and then show the new status"
            Write-Host "3`: Exit without running the command"
            $appuserchoice = Read-Host "Please select from this list (1-3)"
            if ($appuserchoice -eq "") { $appuserchoice = 1}
            if ($appuserchoice -eq 2) { $showsla = $true}
            if ($appuserchoice -eq 3)
            {
                return
            }
        }
        if ($userchoice -eq 2)
        {
            Write-Host ""
            $logicalgroupgrab = Get-AGMLogicalGroup -sort name:asc | where-object {$_.sla.length -gt 0} | Select-Object id,name

            $printarray = @()
            $i = 1
            foreach ($group in $logicalgroupgrab)
            {
                $printarray += [pscustomobject]@{
                    id = $i
                    groupname = $group.name
                    logicalgroupid = $group.id
                }
                $i += 1
            }
            $printarray | Format-Table

            While ($true) 
            {
                Write-host ""
                $listmax = $printarray.logicalgroupid.count
                [int]$userselection = Read-Host "Please select an ID to run (1-$listmax)"
                if ($userselection -lt 1 -or $userselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $logicalgroupid = $printarray.logicalgroupid[($userselection - 1)]

            Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
            Write-Host ""
            Write-Host "Set-AGMLibSLA -logicalgroupid $logicalgroupid $command"
            Write-Host ""
            Write-Host "1`: Run the command now (default)"
            Write-Host "2`: Run the command now and then show the new status"
            Write-Host "3`: Exit without running the command"
            $groupuserchoice = Read-Host "Please select from this list (1-3)"
            if ($groupuserchoice -eq "") { $groupuserchoice = 1}
            if ($groupuserchoice -eq 2) { $showsla = $true}
            if ($groupuserchoice -eq 3)
            {
                return
            }
        }
        if ($userchoice -eq 3)
        {
            Write-Host ""
            Write-Host "Are you sure?  This will affect every Application known to AGM."
            Write-Host "1`: Let me think about this (default)"
            Write-Host "2`: Yes I am sure, lets continue"
            $userchoice = Read-Host "Please select from this list (1-2)"
            if ($userchoice -ne 2)
            {
                return
            } else {
                $everysla = $true
            }
            Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
            Write-Host ""
            Write-Host "Set-AGMLibSLA -everysla$command"
            Write-Host ""
            Write-Host "1`: Run the command now and exit (default)"
            Write-Host "2`: Run the command now and then show the new settings"
            Write-Host "3`: Exit without running the command"
            $everyuserchoice = Read-Host "Please select from this list (1-3)"
            if ($everyuserchoice -eq "") { $everyuserchoice = 1}
            if ($everyuserchoice -eq 2) { $showsla = $true}
            if ($everyuserchoice -eq 3)
            {
                return
            }
        }
       
    }
    if ((!($scheduler)) -and (!($expiration)))
    {
        Get-AGMErrorMessage -messagetoprint "You need to specify -scheduler enable  or  -scheduler disable    and/or   -expiration enable  or  -expiration disable "
        return
    }

    if ($slaid) 
    {
        if ((!($scheduler)) -and ($expiration))
        {
            Set-AGMSLA -slaid $slaid -expiration $expiration
        }
        if (($scheduler) -and (!($expiration)))
        {
            Set-AGMSLA -slaid $slaid -scheduler $scheduler
        }
        if (($scheduler) -and ($expiration))
        {
            Set-AGMSLA -slaid $slaid -expiration $expiration -scheduler $scheduler
        }
    }
    if ($logicalgroupid) 
    {
        if ((!($scheduler)) -and ($expiration))
        {
            Set-AGMSLA -logicalgroupid $logicalgroupid -expiration $expiration
        }
        if (($scheduler) -and (!($expiration)))
        {
            Set-AGMSLA -logicalgroupid $logicalgroupid -scheduler $scheduler
        }
        if (($scheduler) -and ($expiration))
        {
            Set-AGMSLA -logicalgroupid $logicalgroupid -expiration $expiration -scheduler $scheduler
        }
    }
    if ($everysla)
    {
        $slagrab = Get-AGMSLA   
        foreach ($sla in $slagrab)
        {
            $target = $sla.id
            if ((!($scheduler)) -and ($expiration))
            {
                Set-AGMSLA -slaid $target -expiration $expiration
            }
            if (($scheduler) -and (!($expiration)))
            {
                Set-AGMSLA -slaid $target -scheduler $scheduler
            }
            if (($scheduler) -and ($expiration))
            {
                Set-AGMSLA -slaid $target -expiration $expiration -scheduler $scheduler
            }
        }
    }
    if ($showsla -eq $true)
    {
        if ($slaid) { Get-AGMLibSLA -slaid $slaid}
        if ($logicalgroupid) { Get-AGMLibSLA -logicalgroupid $logicalgroupid}
        if ($everysla) 
        { 
            Get-AGMLibSLA
            Read-Host -Prompt "Press enter to continue"
        }
    }
}