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


Function Set-AGMLibApplianceParameter([string]$applianceid,[string]$id,[string]$param,[string]$value) 
{
    <#
    .SYNOPSIS
    Sets parameters on appliances.
    Using this means you do not have to access the appliance directly to change the parameter
    When you set the value, the previous and new values will be reported.
    If an error occurs this will be reported.

    .EXAMPLE
    Set-AGMLibApplianceParameter -id 1234 -param maxsnapslots -value 10
    Sets the maxsnapslots param to a value of 10 on the appliance with ID 1234

    .DESCRIPTION
    A function to set parameters

    #>

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
    if ($id)
    { $applianceid = $id }
    
    # first we need an applianceid
    if (!($applianceid))
    {
        $appliancegrab = Get-AGMAppliance
        if ($appliancegrab.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any appliances with Get-AGMAppliance"
            return
        }
        if ($appliancegrab.id.count -eq 1)
        {
            $applianceid = $appliancegrab.id
        }
        if ($appliancegrab.id.count -gt 1)
        {
            write-host ""
            write-host "Appliance Selection"
            write-host ""
            $i = 1
            foreach ($appliance in $appliancegrab.name)
            { 
                Write-Host -Object "$i`: $appliance"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $appliancegrab.id.count
                [int]$appselection = Read-Host "Please select an appliance (1-$listmax)"
                if ($appselection -lt 1 -or $appselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $applianceid =  $appliancegrab.name[($appselection - 1)]
        }
    } 
    if (!($param)) 
    {
        [string]$param = Read-Host "Which param do you wish to set"
    }
    if (!($value)) 
    {
        [string]$value = Read-Host "Desired value for $param"
    }


    $oldvaluegrab = Get-AGMAPIApplianceInfo -applianceid $applianceid -command "getparameter" -arguments "param=$param"
    $set = Set-AGMAPIApplianceTask -applianceid $applianceid -command "setparameter" -arguments "param=$param&value=$value"
    $newvaluegrab = Get-AGMAPIApplianceInfo -applianceid $applianceid -command "getparameter" -arguments "param=$param"
    $oldvalue = $oldvaluegrab.$param
    $newvalue = $newvaluegrab.$param
    if ($set.err_message)
    {
        $set
    }
    else
    {
        write-host ""
        write-host "$param changed from $oldvalue to $newvalue"
        write-host ""
    }
}