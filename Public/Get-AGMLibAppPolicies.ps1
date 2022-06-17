
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

Function Get-AGMLibAppPolicies ([string]$appid) 
{
    <#
    .SYNOPSIS
    Get policy IDs for an app

    .EXAMPLE
    Get-AGMLibAppPolicies
    You will be prompted for Application ID

    .EXAMPLE
    Get-AGMLibAppPolicies 2133445
    Get the policies for AppID 2133445

    .EXAMPLE
    Get-AGMLibAppPolicies  -appid 2133445 
    Get the policies for AppID 2133445

    .DESCRIPTION
    A function to get the policies for a specified app

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
    

    if  (!($appid))
    {
        [string]$appid = Read-Host "AppID"
    }  

    $appgrab = Get-AGMApplication -filtervalue appid=$appid 
    
    $sltid = $appgrab.sla.slt.id
    
    if (!($sltid))
    {
        Get-AGMErrorMessage -messagetoprint "Failed to learn SLT ID for specified ID"
        return
    }
    else 
    {
    $policygrab = Get-AGMSltPolicy -id $sltid
    }
    if (!($policygrab))
    {
        Get-AGMErrorMessage -messagetoprint "Failed to learn Policies for SLT ID $sltid"
        return
    }
    else 
    {
        foreach ($policy in $policygrab)
        {

            if ($policy.op -eq "snap") { $operation = "snapshot" }
            elseif ($policy.op -eq "cloud")
            { $operation = "onvault" }
            else {
                $operation = $policy.op
            }  
            $policy | Add-Member -NotePropertyName operation -NotePropertyValue $operation
            $policy | Add-Member -NotePropertyName policyid -NotePropertyValue $policy.id
            if ($policy.retention)
            {
                $policy.retention = $policy.retention + " " + $policy.retentionm
            }
            if ($policy.rpo)
            {
                $policy.rpo = $policy.rpo + " " + $policy.rpom
            }
            if ($policy.starttime)
            {
                $st = [timespan]::fromseconds($poliy.starttime)
                $policy.starttime = $st.ToString("hh\:mm")
            }
            if ($policy.endtime)
            {
                $et = [timespan]::fromseconds($policy.endtime)
                $policy.endtime = $et.ToString("hh\:mm")
            }
        }
        $policygrab | select-object policyid,name,operation,priority,retention,starttime,endtime,rpo
    }    
}