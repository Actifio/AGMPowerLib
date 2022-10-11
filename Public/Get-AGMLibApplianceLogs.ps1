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

Function Get-AGMLibApplianceLogs([string]$applianceid,[string]$id,[string]$logtypes,[string]$startdate,[string]$enddate,[string]$hostid) 
{
    <#
    .SYNOPSIS
    Fetches output logs from appliances.  This means we dont need access to the appliance to do this.
    We need to supply an ID for the relevant Appliance.
    You can learn the applianceid by running Get-AGMAppliance and using the value in the id field for the relevant appliance
    The output file will be a zip file with the current date in format YYYY-MM-DD HH-mm-ss.zip

    .EXAMPLE
    Get-AGMLibApplianceLogs -applianceid 1234 -logtypes "patch,tomcat"
    Gets the patch and tomcat logs for appliance with ID 1234 for the last three days

    .EXAMPLE
    Get-AGMLibApplianceLogs -applianceid 1234 -logtypes "agent" -hostid "460500"
    Gets the agent log from host ID 460500.   Learn hostid with Get-AGMHost
    Note that if your using this with an Actifio AGM, use "connector" instead or "agent"

    .EXAMPLE
    Get-AGMLibApplianceLogs -logtypes "udppm,psrv" -startdate "2022-10-01" -enddate "2022-10-04"
    Gets the udppm and psrv logs for the specified three days.  Because this management console has only one appliance, no applianceid was needed

    .DESCRIPTION
    A function to get logs.  

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
            write-host "Select which Appliance you wish to get logs from"
            write-host ""
            $i = 1
            foreach ($appliance in $appliancegrab)
            { 
                $id = $appliance.id
                $name = $appliance.name
                Write-Host -Object "$i`: $name (applianceid: $id)"
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
            $applianceid =  $appliancegrab.id[($appselection - 1)]
        }
    } 
    $timeout = $AGMTIMEOUT
    if (!($logtypes))
    {
        write-host "Valid log types are as follows.  Use exact syntax command separated"
        Write-host "
        appliance
        cloudbacker
        database
        flasher
        install
        network
        omd
        patch
        psrv
        streadmsnapd
        systemlog
        tomcat
        udppm
        supportbundle
        agent
        connector"
        write-host ""
        $logtypes = Read-Host "Enter desired log types, comma separated"
    }
    $zipfilename = "$(get-date -f "yyyy-MM-dd HH-MM-ss").zip"
    if (!($startdate)) { $startdate = "$((get-date).adddays(-3).ToString("yyyy-MM-dd"))" }
    if (!($enddate)) { $enddate = "$((get-date).ToString("yyyy-MM-dd"))" }
    $command = "?startdate=$startdate&enddate=$enddate&logtypes=$logtypes"
    if ($hostid)
    {
        $hostgrab = Get-AGMHost -id $hostid
        if (!($hostgrab.srcid))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find srcid from host with ID $hostid using command:   Get-AGMHost -id $hostid"
            return
        }
        else {
            $srcid = $hostgrab.srcid
            $command = "?startdate=$startdate&enddate=$enddate&logtypes=$logtypes&hostid=$srcid"
        }
    }
    Try
    {
        $url = "https://$AGMIP/actifio/appliancedelegation/$applianceid/config/download/log" + "$command" 
        if  ($arguments)
        {
            $url = $url +"?" +$arguments
        }
        if ($IGNOREAGMCERTS)
        {
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method "Get" -ContentType "application/zip" -Headers @{ Authorization = "Actifio $AGMSESSIONID" } -Uri "$url" -TimeoutSec $timeout -OutFile $zipfilename
        }
        else
        {
            if ($AGMToken)
            {
                $resp = Invoke-RestMethod -Method "Get" -ContentType "application/zip" -Headers @{ Authorization = "Bearer $AGMToken"; "backupdr-management-session" = "Actifio $AGMSESSIONID" } -Uri "$url" -TimeoutSec $timeout -OutFile $zipfilename
            }
            else
            {
                $resp = Invoke-RestMethod -Method "Get" -ContentType "application/zip" -Headers @{ Authorization = "Actifio $AGMSESSIONID" } -Uri "$url" -TimeoutSec $timeout -OutFile $zipfilename
            }
        }
    }
    Catch
    {
        if ( $((get-host).Version.Major) -gt 5 )
        {
            $RestError = $_
        }
        else 
        {
            if ($_.Exception.Response)
            {
                $result = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($result)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $RestError = $reader.ReadToEnd();
            }
            else 
            {
                Get-AGMErrorMessage  -messagetoprint  "No response was received from $AGMIP  Timeout is set to $timeout seconds"
                return
            }
        }
    }
    if ($RestError)
    {
        Test-AGMJSON $RestError 
    }
    elseif ($resp.result)
    {
        $resp.result
    }
    else 
    {
        $resp    
    }      
}