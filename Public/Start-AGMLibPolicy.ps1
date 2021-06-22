function Start-AGMLibPolicy ([string]$policyid,[string]$jobclass,[string]$label)
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
    Start-AGMLibPolicy -policyid 1234 -label "testrun"
    Runs on-demand jobs for all apps using policy ID 1234 where each image gets a label of "testrun"

    .DESCRIPTION
    A function to start large numbers of on-demand jobs

    -policyid       Will start an on-demand job for all apps using this policy ID

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
        Clear-Host
        write-host "Policy ID selection menu.  Please select which Policy ID will be run"
        Write-host ""

        $i = 1
        foreach
        ($policy in $policygrab)
        { 
            Write-Host -Object "$i`:  SLTname: $($policy.sltname)  PolicyName: $($policy.sltname)   PolicyID:  $($policy.id)   Type:  $($policy.op)"
            $i++
        }
        
        While ($true) 
        {
            Write-host ""
            $listmax = $policygrab.sltid.count
            [int]$userselection = Read-Host "Please select a policy ID to run (1-$listmax)"
            if ($userselection -lt 1 -or $userselection -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
            } 
            else
            {
                break
            }
        }
        $policyid = $policygrab.id[($userselection - 1)]
        $sltname = $policygrab.sltname[($userselection - 1)]
        $optype = $policygrab.op[($userselection - 1)]
       # help the user
       write-host -nonewline  "Run this command: Start-AGMLibPolicy -policyid $policyid"
       break
   }

   # we now have to find all apps using this policy and run a backup for each one.   
   $applist = Get-AGMApplication -filtervalue sltname=$sltname
   if ($applist.count -eq 0)
   {
       Get-AGMErrorMessage -messagetoprint "Failed to find any applications using policy ID $policyid  and SLT Name $sltname.  Please check the Policy ID with Get-AGMLibPolicies."
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

   foreach ($appid in $applist.id)
   {
        write-host "Starting job for appid $appid using $optype policy ID $policyid from SLT $sltname"
        Post-AGMAPIData  -endpoint /application/$appid/backup -body $json
   }
}