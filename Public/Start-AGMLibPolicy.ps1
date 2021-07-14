function Start-AGMLibPolicy ([string]$policyid,[string]$label,[string]$backuptype)
{
    <#
    .SYNOPSIS
    Runs on-demand jobs for one policy

    .EXAMPLE
    Start-AGMLibPolicy
    Runs a guided menu to let you start a policy or policies in an SLT

    .EXAMPLE
    Start-AGMLibPolicy -policyid 1234 
    Runs on-demand jobs for all apps using policy ID 1234

    .EXAMPLE
    Start-AGMLibPolicy -policyid 1234 -backuptype db
    Runs on-demand jobs for all apps using policy ID 1234 with a backup type of DB
    If the application if not a database type, in that the appclass field for that application is blank, then the backuptype will be ignored.

    .EXAMPLE
    Start-AGMLibPolicy -policyid 1234 -label "testrun"
    Runs on-demand jobs for all apps using policy ID 1234 where each image gets a label of "testrun"

    .DESCRIPTION
    A function to start large numbers of on-demand jobs

    -policyid       Will start an on-demand job for all apps using this policy ID
    -backuptype <type>  Where type needs to be db, dblog or log

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

   # will need this later to handle DBs.
   if ($capturetype)
   {
       $backuptype = $capturetype
   }
   if ($backuptype)
   {
       if (( $backuptype -ne "db") -and ( $backuptype -ne "log") -and ( $backuptype -ne "dblog"))
       {
           Get-AGMErrorMessage -messagetoprint "Requested backuptype $backuptype is invalid, use either `'-backuptype db`' or `'-backuptype log`' or `'-backuptype dblog`'"
           return
       }
   }
   if (!($backuptype))
   {
       $backuptype = ""
   }

   # we could let user fail, but this is a composite function, so lets be polite.
   if ($policyid)
   {
       $policygrab = Get-AGMLibPolicies  | where-object { $_.id -eq $policyid }
       if ($policygrab.op.count -ne 1)
       {
           Get-AGMErrorMessage -messagetoprint "Failed to find policy ID $policyid  Please check the Policy ID with Get-AGMLibPolicies"
           return
       }
       $sltname = $policygrab.sltname
       $optype = $policygrab.op
   }

   #  if we have got to here and have no policy ID, we go to guided mode
   if (!($policyid))
   {     
        $policygrab = Get-AGMLibPolicies 
        $printarray = @()
        $i = 1
            foreach ($policy in $policygrab)
            {
                if ($policy.op -eq "snap") { $operation = "snapshot" }
                    elseif ($policy.op -eq "cloud")
                    { $operation = "onvault" }
                    else {
                        $operation = $policy.op
                    }  
                $printarray += [pscustomobject]@{
                    id = $i
                    sltname = $policy.sltname
                    policyname = $policy.name
                    policyid = $policy.id
                    operation = $operation
                    retention = $policy.retention
                }
                $i += 1
            }


        Clear-Host
        write-host "Policy ID selection menu.  Please select which Policy ID will be run"
        Write-host ""
        $printarray | Format-Table
        While ($true) 
        {
            Write-host ""
            $listmax = $policygrab.sltid.count
            [int]$userselection = Read-Host "Please select a ID to run (1-$listmax)"
            if ($userselection -lt 1 -or $userselection -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
            } 
            else
            {
                break
            }
        }
        $policyid = $printarray.policyid[($userselection - 1)]
        $sltname = $printarray.sltname[($userselection - 1)]
        $optype = $printarray.operation[($userselection - 1)]
       
       #  
       if (!($backuptype))
        {
            Write-Host ""
            Write-Host "Backup Type (this is only applied to database applications with a defined appclass"
            Write-Host "1`: Non-Database(default)"
            Write-Host "2`: DB"
            Write-Host "3`: DB+Log"
            Write-Host "4`: Log"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-4)"
            if ($userselection -eq 2) {  $backuptype = "db"  }
            if ($userselection -eq 3) {  $backuptype = "dblog"  }
            if ($userselection -eq 4) {  $backuptype = "log"  }
        } 

        # help the user
       Write-Host ""
       Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
       Write-Host ""
       if ($backuptype) { write-host "Start-AGMLibPolicy -policyid $policyid -backuptype $backuptype"} else { write-host "Start-AGMLibPolicy -policyid $policyid"}
       Write-Host ""
       Write-Host "1`: Run the command now (default)"
       Write-Host "2`: Exit without running the command"
       $userchoice = Read-Host "Please select from this list (1-2)"
       if ($userchoice -eq "") { $userchoice = 1 }
       if ($userchoice -eq 2)
       {
           return
       }
   }

   # we now have to find all apps using this policy and run a backup for each one.   
   $applist = Get-AGMApplication -filtervalue sltname=$sltname
   if ($applist.count -eq 0)
   {
       Get-AGMErrorMessage -messagetoprint "Failed to find any applications using policy ID $policyid  and SLT Name $sltname."
       return
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

   foreach ($app in $applist)
   {
        $appname = $app.appname
        $appid = $app.id
        $hostname = (($app).host).hostname
        # if there is no appclass, lets assume it is not a database and not cause confused errors.
        if (($backuptype) -and ($app.appclass))
        {
            write-host "Starting job for hostname: $hostname   appname: $appname   appid: $appid using: $optype policyID: $policyid from SLTName: $sltname with backuptype: $backuptype"
        }
        else {
            write-host "Starting job for hostname: $hostname   appname: $appname   appid: $appid using: $optype policyID: $policyid from SLTName: $sltname"
        }
        Post-AGMAPIData  -endpoint /application/$appid/backup -body $json
   }
}