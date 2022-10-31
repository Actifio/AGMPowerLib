# Copyright 2022 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Start-AGMLibPolicy ([string]$policyid,[string]$logicalgroupid,[string]$label,[string]$backuptype)
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
    -logicalgroupid   WIll start on-demand job for all members of the logical group

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
        $sessiontest
       return
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

   # if asked for logicalgroupid
   if ($logicalgroupid)
   {
       $groupgrab = Get-AGMLogicalGroup -id $logicalgroupid
       if ($groupgrab.err_code)
       {
        $groupgrab
        return
       }
   }


   # we could let user fail, but this is a composite function, so lets be polite.
   if ($policyid)
   {
       $policygrab = Get-AGMLibPolicies  | where-object { $_.policyid -eq $policyid }
       if ($policygrab.operation.count -ne 1)
       {
           Get-AGMErrorMessage -messagetoprint "Failed to find policy ID $policyid  Please check the Policy ID with Get-AGMLibPolicies"
           return
       }
       $sltname = $policygrab.sltname
       $optype = $policygrab.operation
   }

   #  if we have got to here and have no policy ID, we go to guided mode
   if (!($policyid))
   {     
        $policygrab = Get-AGMLibPolicies 
        $printarray = @()
        $i = 1
            foreach ($policy in $policygrab)
            {
                $printarray += [pscustomobject]@{
                    id = $i
                    sltname = $policy.sltname
                    policyname = $policy.name
                    policyid = $policy.policyid
                    operation = $policy.operation
                    retention = $policy.retention
                }
                $i += 1
            }


        Clear-Host
        Write-host "This function is used to start large numbers of on-demand jobs.  This is done by choosing:"
        Write-host "-- The Policy ID to run"
        Write-Host "-- The backup type for any database apps (this is optional)" 
        Write-host "-- A Logical Group (this is optional)"
        Write-host ""
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

        # offer group support
        Write-Host ""
        Write-Host "Do you want to run this policy for a specific group"
        Write-Host "1`: No(default)"
        Write-Host "2`: Yes"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq 2) 
        {  
            $groupgrab = Get-AGMLogicalGroup | where-object { $_.membercount -gt 0 } | where-object { $_.managed -eq "True" } 
            if ($groupgrab.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Failed to find any managed and used Logical groups with Get-AGMLogicalGroup"
                return
            }

            $printarray = @()
            $i = 1
            foreach ($group in $groupgrab)
            {
                $printarray += [pscustomobject]@{
                    id = $i
                    name = $group.name
                    logicalgroupid = $group.id
                    membercount = $group.membercount
                }
                $i += 1
            }


            Clear-Host
            write-host "Logical Group selection menu.  Please select which Logical Group will be run"
            Write-host ""
            $printarray | Format-Table
            While ($true) 
            {
                Write-host ""
                $listmax = $printarray.count
                [int]$userselection = Read-Host "Please select a Logical Group to run (1-$listmax)"
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
        }
        # help the user
       Write-Host ""
       Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
       Write-Host ""
       Write-Host ""
       Write-host -nonewline "Start-AGMLibPolicy -policyid $policyid"
       if ($backuptype) { Write-Host -nonewline " -backuptype $backuptype" }
       if ($logicalgroupid) { Write-Host -nonewline " -logicalgroupid $logicalgroupid" }
       Write-Host ""
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
   
   if ($logicalgroupid)
   {    
        $applist = (Get-AGMLogicalGroupMember -id $logicalgroupid).sources
   } else {
        $applist = Get-AGMApplication -filtervalue sltname=$sltname
   }
   
   if ($applist.count -eq 0)
   {
       Get-AGMErrorMessage -messagetoprint "Failed to find any applications using policy ID $policyid and SLT Name $sltname."
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
        if (($app).host)
        { $hostname = (($app).host).hostname }
        else {
            $hostname = $appname
        }
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