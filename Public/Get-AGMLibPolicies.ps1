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


Function Get-AGMLibPolicies([string]$appid,[string]$sltid,[switch]$advancedpolicysettings,[switch]$snapshotlocation,[switch]$enforcedretention) 
{
    <#
    .SYNOPSIS
    Get SLT policies

    .EXAMPLE
    Get-AGMLibPolicies

    .EXAMPLE
    Get-AGMLibPolicies -appid 2133445
    Get the policies for AppID 2133445

    .EXAMPLE
    Get-AGMLibPolicies -sltid 2133445 
    Get the policies for SLT ID 2133445

    .DESCRIPTION
    A function to get policies

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    $sessiontest = Get-AGMVersion
    if (($sessiontest.errormessage) -or (!($sessiontest)))
    {
        $sessiontest
        return
    }

    if ($sltid)
    {
        $sltgrab = Get-AGMSLT -id $sltid | select-object id,name | sort-object name
    }
    if ($appid)
    {
        $appgrab = Get-AGMApplication -filtervalue appid=$appid 
        $sltid = $appgrab.sla.slt.id
        if ($sltid.length -gt 0)
        {
            $sltgrab = Get-AGMSLT -id $sltid | select-object id,name | sort-object name
        }
    }
    if ( (!($appid)) -and (!($sltid)) )
    {
        $sltgrab = Get-AGMSLT | select-object id,name | sort-object name
    }
    
    
    if (($sltgrab.id.count -eq 0) -and ($appid))
    {
        Get-AGMErrorMessage -messagetoprint "Failed to find any SLTs for Appid $appid"
        return
    }
    elseif (($sltgrab.id.count -eq 0) -and ($sltid))
    {
        Get-AGMErrorMessage -messagetoprint "Failed to find any SLTs for SLT ID $sltid"
        return
    }
    elseif ($sltgrab.id.count -eq 0)
    {
        Get-AGMErrorMessage -messagetoprint "Failed to find any SLTs"
        return
    }

    foreach ($slt in $sltgrab)
    {
        $sltname = $slt.name
        $appcount = Get-AGMApplicationCount -filtervalue sltname=$sltname
        $policygrab = Get-AGMSLTpolicy -id $slt.id
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
            $policy | Add-Member -NotePropertyName sltid -NotePropertyValue $slt.id 
            $policy | Add-Member -NotePropertyName sltname -NotePropertyValue $slt.name
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
                $st = [timespan]::fromseconds($policy.starttime)
                $policy.starttime = $st.ToString("hh\:mm")
            }
            if ($policy.endtime)
            {
                $et = [timespan]::fromseconds($policy.endtime)
                $policy.endtime = $et.ToString("hh\:mm")
            }
            if (($advancedpolicysettings) -or ($enforcedretention) -or ($snapshotlocationvalue))
            {
                $tablegrab = Get-AGMSLTpolicy -id $slt.id -policyid $policy.id -settableoption
                if (($tablegrab.name) -and ($enforcedretention))
                {  
                    $enforcedretentionvalue = ($tablegrab | where-object { $_.name -eq "immutabilitydays" }).value
                    if (($enforcedretentionvalue -eq "") -or ($enforcedretentionvalue -eq $null)) { $enforcedretentionvalue = "0"}
                    $policy | Add-Member -NotePropertyName enforcedretentiondays -NotePropertyValue $enforcedretentionvalue
                }
               if (($tablegrab.name) -and ($snapshotlocation))
                {  
                    $snapshotlocationvalue = ($tablegrab | where-object { $_.name -eq "snapshotlocationvalue" }).value
                    if (!($snapshotlocationvalue)) { $snapshotlocationvalue = "Based on the source disk location"}
                    if ($operation -eq "snapshot")
                    {
                        $policy | Add-Member -NotePropertyName snapshotlocation -NotePropertyValue $snapshotlocationvalue
                    }
                }
                if (($tablegrab.name) -and ($advancedpolicysettings))
                {
                    foreach ($tableentry in $tablegrab)
                    {
                        $policy | Add-Member -NotePropertyName $tableentry.name -NotePropertyValue $tableentry.value
                    }
                }
            }
            $policy | Add-Member -NotePropertyName appcount -NotePropertyValue $appcount
    
        }
        if (($enforcedretention) -and ($snapshotlocation))
        {
            $policygrab | select-object sltid,sltname,policyid,name,operation,retention,starttime,endtime,rpo,appcount,priority,snapshotlocation,enforcedretentiondays
        }
        elseif ($enforcedretention) 
        {
            $policygrab | select-object sltid,sltname,policyid,name,operation,retention,starttime,endtime,rpo,appcount,priority,enforcedretentiondays
        }
        elseif ($snapshotlocation)
        {
            $policygrab | select-object sltid,sltname,policyid,name,operation,retention,starttime,endtime,rpo,appcount,priority,snapshotlocation
        }
        elseif ($advancedpolicysettings)
        {
            $policygrab | Select-Object -ExcludeProperty "@type",id,href,exclusioninterval,exclusiontype,op,verification,retentionm,repeatinterval,reptype,rpom,scheduletype,slection,slt,remoteretention,iscontinuous,selection,sourcevault,targetvault
        } 
        else
        {
            $policygrab | select-object sltid,sltname,policyid,name,operation,retention,starttime,endtime,rpo,appcount,priority
        }
        
    }  
}
