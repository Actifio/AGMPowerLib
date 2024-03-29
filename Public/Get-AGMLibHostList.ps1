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


Function Get-AGMLibHostList ([string]$ostype)
{
    <#
    .SYNOPSIS
    Displays the Host IDs for nominated host types.

    .EXAMPLE
    Get-AGMLibHostList 
    You will be prompted for information


    .DESCRIPTION
    A function to find Host IDs

    #>

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

    $appliancegrab = Get-AGMAppliance | select-object name,clusterid | sort-object name
    if ($appliancegrab.count -eq 0)
    {
        Get-AGMErrorMessage -messagetoprint "Failed to find any appliances to work with"
        return
    }
    if ($appliancegrab.name.count -eq 1)
    {
        $mountapplianceid = $appliancegrab.clusterid
    }
    else
    {
        Clear-Host
        write-host "Appliance selection menu - which Appliance will run your mounts"
        Write-host ""
        $i = 1
        foreach ($appliance in $appliancegrab)
        { 
            Write-Host -Object "$i`: $($appliance.name)"
            $i++
        }
        While ($true) 
        {
            Write-host ""
            $listmax = $appliancegrab.name.count
            [int]$appselection = Read-Host "Please select an Appliance to mount from (1-$listmax)"
            if ($appselection -lt 1 -or $appselection -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
            } 
            else
            {
                break
            }
        }
        $mountapplianceid =  $appliancegrab.clusterid[($appselection - 1)]
    }
    if ($ostype)
    {
        if ($ostype -ne "Linux")
        {
            if ($ostype -ne "Win32")
            {
                Get-AGMErrorMessage -messagetoprint "ostype needs to be either Linux or Win32"
                return
            }
        } 
    }
    if ($ostype -eq "linux") { $ostype = "Linux" }
    if ($ostype -eq "win32") { $ostype = "Win32" }

    if (!($ostype))
    {
        Clear-Host
        Write-Host "Are the scanning hosts Linux or Windows?"
        Write-host ""
        Write-Host "1`: Linux"
        Write-Host "2`: Windows"
        Write-Host "3`: Exit"
        $userchoice3 = Read-Host "Please select from this list (1-3)"
        if ($userchoice3 -eq "" -or $userchoice3 -eq 3)  { return }
        if ($userchoice3 -eq 1)
        {
            $ostype = "Linux"
        }
        if ($userchoice3 -eq 2)
        {
            $ostype = "Win32"
        }
    }
    $hostgrab = Get-AGMHost -filtervalue "sourcecluster=$mountapplianceid&ostype=$ostype" -sort "name:asc"
    if ($hostgrab.id.count -eq 0)
    {
        Get-AGMErrorMessage -messagetoprint "No hosts were found with selected ostype $ostype"
        return
    }
    Clear-Host
    Write-Host "Target host selection menu"
    $hostgrab  | Select-Object id,hostname,ostype,@{N='ApplianceName'; E={$_.appliance.name}} | Format-Table    
}
