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


Function New-AGMLibGCPInstanceMultiMount ([string]$instancelist,[switch]$textoutput,[decimal]$limit) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of GCP Instance data to create many new GCP Instances

    .EXAMPLE
    New-AGMLibGCPInstanceMultiMount -instancelist recoverylist.csv

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibGCPInstance jobs

    .EXAMPLE
    New-AGMLibGCPInstanceMultiMount -instancelist recoverylist.csv -textoutput

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibGCPInstance jobs
    Rather than wait for all jobs to be attemped before reporting status, a report will be displayed after each job is attempted.

    .DESCRIPTION
    This routine needs a well formatted CSV file.    Here is an example of such a file:

    srcid,appname,projectname,zone,instancename,machinetype,serviceaccount,networktags,poweronvm,labels,disktype,nic0hostproject,nic0network,nic0subnet,nic0externalip,nic0internalip,nic1hostproject,nic1network,nic1subnet,nic1externalip,nic1internalip
    28417,lab2tiny,project1,australia-southeast1-a,gcetest2,e2-micro,,,TRUE,,pd-ssd,,network3,sydney,,,,,,
    28417,mysq57,project1,australia-southeast1-a,gcetest3,e2-micro,,,TRUE,,pd-ssd,,network3,sydney,,,,,,
    28417,postgres11,project1,australia-southeast1-a,gcetest4,e2-micro,,,TRUE,,pd-ssd,,network3,sydney,,,,,,
 
    If you specify both appname and appid then appid will be used.  The appname is mandatory so you know the name of the source VM.
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
    
    if (!($instancelist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a csv file correctly formatted as per the help for this function using: -instancelist xxxx.csv"
        return;
    }

    if ( Test-Path $instancelist )
    {
        $recoverylist = Import-Csv -Path $instancelist
    }
    else
    {
        Get-AGMErrorMessage -messagetoprint "GCP Instance list: $instancelist could not be opened."
        return;
    }

    # first we quality check the CSV
    if ($recoverylist.srcid -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: srcid" ;return }
    if ($recoverylist.projectname -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: projectname" ;return }
    if ($recoverylist.machinetype -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: machinetype" ;return }
    if ($recoverylist.instancename -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: instancename" ;return }
    if ($recoverylist.nic0network -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: nic0network" ;return }
    if ($recoverylist.nic0subnet -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: nic0subnet" ;return }
    if ($recoverylist.zone -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: zone" ;return }
    if (($recoverylist.appname -eq $null) -and ($recoverylist.appid -eq $null))  {  Get-AGMErrorMessage -messagetoprint "Could not find either appid or appname columns" ; return }

    # dry run for srcid and appname
    $row =1
    foreach ($app in $recoverylist)
    {
        if ($app.srcid -eq "") { write-host  "The following mandatory value is missing: srcid in row $row" ; return }
        $row += 1
    }
    $row =1
    foreach ($app in $recoverylist)
    {
        if ($app.appname -eq "")  { write-host "The following mandatory value is missing: appname row $row" ; return}
        $row += 1
    }
    if (!($limit))
    {
        $limit = 5
    }


    write-host ""
    if (!($textoutput))
    {
        $printarray = @()
    }
    if ( $((get-host).Version.Major) -gt 6 )
    {
        if ($AGMToken)
        {
            $recoverylist | ForEach-Object -parallel {
                $mountcommand = 'New-AGMLibGCPInstance -srcid ' +$_.srcid +' -zone ' +$_.zone +' -projectname ' +$_.projectname +' -machinetype ' +$_.machinetype +' -instancename ' +$_.instancename +' -nic0network "' +$_.nic0network +'" -nic0subnet "' +$_.nic0subnet +'"'
                if ($_.nic0hostproject) { $mountcommand = $mountcommand + ' -nic0hostproject "' +$_.nic0hostproject +'"' }
                if ($_.appid) { $mountcommand = $mountcommand + ' -appid "' +$_.appid +'"' }
                if ($_.appname) {  $mountcommand = $mountcommand + ' -appname "' +$_.appname +'"' }
                if ($_.networktags) { $mountcommand = $mountcommand + ' -networktags "' +$_.networktags +'"' } 
                if ($_.serviceaccount) { $mountcommand = $mountcommand + ' -serviceaccount "' +$_.serviceaccount +'"'} 
                if ($_.labels) { $mountcommand = $mountcommand + ' -labels "' +$_.labels +'"' } 
                if ($_.nic0externalip) { $mountcommand = $mountcommand + ' -nic0externalip ' +$_.nic0externalip } 
                if ($_.nic0internalip) { $mountcommand = $mountcommand + ' -nic0internalip ' +$_.nic0internalip } 
                if ($_.nic1hostproject) { $mountcommand = $mountcommand + ' -nic1hostproject "' +$_.nic1hostproject +'"' }
                if ($_.nic1network) { $mountcommand = $mountcommand + ' -nic1network "' +$_.nic1network +'"'} 
                if ($_.nic1subnet) { $mountcommand = $mountcommand + ' -nic1subnet "' +$_.nic1subnet +'"'} 
                if ($_.nic1internalip) { $mountcommand = $mountcommand + ' -nic1internalip ' +$_.nic1internalip } 
                if ($_.nic1externalip) { $mountcommand = $mountcommand + ' -nic1externalip ' +$_.nic1externalip } 
                if ($_.nic2hostproject) { $mountcommand = $mountcommand + ' -nic2hostproject "' +$_.nic2hostproject +'"' }
                if ($_.nic2network) { $mountcommand = $mountcommand + ' -nic2network "' +$_.nic2network +'"'} 
                if ($_.nic2subnet) { $mountcommand = $mountcommand + ' -nic2subnet "' +$_.nic2subnet +'"'} 
                if ($_.nic2internalip) { $mountcommand = $mountcommand + ' -nic2internalip ' +$_.nic2internalip } 
                if ($_.nic2externalip) { $mountcommand = $mountcommand + ' -nic2externalip ' +$_.nic2externalip } 
                if ($_.nic3hostproject) { $mountcommand = $mountcommand + ' -nic3hostproject "' +$_.nic3hostproject +'"' }
                if ($_.nic3network) { $mountcommand = $mountcommand + ' -nic3network "' +$_.nic3network +'"'} 
                if ($_.nic3subnet) { $mountcommand = $mountcommand + ' -nic3subnet "' +$_.nic3subnet +'"'} 
                if ($_.nic3internalip) { $mountcommand = $mountcommand + ' -nic3internalip ' +$_.nic3internalip } 
                if ($_.nic3externalip) { $mountcommand = $mountcommand + ' -nic3externalip ' +$_.nic3externalip } 
                if ($_.poweronvm) { $mountcommand = $mountcommand + ' -poweronvm ' + $_.poweronvm } 
                if ($_.retainlabel) { $mountcommand = $mountcommand + ' -retainlabel ' + $_.retainlabel } 
                $agmip = $using:agmip 
                $AGMToken = $using:AGMToken 
                $AGMSESSIONID = $using:AGMSESSIONID
                Invoke-Expression $mountcommand 
                Start-Sleep -seconds 15
            } -throttlelimit $limit
        }
        else 
        {
            $recoverylist | ForEach-Object -parallel {
                $mountcommand = 'New-AGMLibGCPInstance -srcid ' +$_.srcid +' -zone ' +$_.zone +' -projectname ' +$_.projectname +' -machinetype ' +$_.machinetype +' -instancename ' +$_.instancename +' -nic0network "' +$_.nic0network +'" -nic0subnet "' +$_.nic0subnet +'"'
                if ($_.nic0hostproject) { $mountcommand = $mountcommand + ' -nic0hostproject "' +$_.nic0hostproject +'"' }
                if ($_.appid) { $mountcommand = $mountcommand + ' -appid "' +$_.appid +'"' }
                if ($_.appname) {  $mountcommand = $mountcommand + ' -appname "' +$_.appname +'"' }
                if ($_.networktags) { $mountcommand = $mountcommand + ' -networktags "' +$_.networktags +'"' } 
                if ($_.serviceaccount) { $mountcommand = $mountcommand + ' -serviceaccount "' +$_.serviceaccount +'"'} 
                if ($_.labels) { $mountcommand = $mountcommand + ' -labels "' +$_.labels +'"' } 
                if ($_.nic0externalip) { $mountcommand = $mountcommand + ' -nic0externalip ' +$_.nic0externalip } 
                if ($_.nic0internalip) { $mountcommand = $mountcommand + ' -nic0internalip ' +$_.nic0internalip } 
                if ($_.nic1hostproject) { $mountcommand = $mountcommand + ' -nic1hostproject "' +$_.nic1hostproject +'"' }
                if ($_.nic1network) { $mountcommand = $mountcommand + ' -nic1network "' +$_.nic1network +'"'} 
                if ($_.nic1subnet) { $mountcommand = $mountcommand + ' -nic1subnet "' +$_.nic1subnet +'"'} 
                if ($_.nic1internalip) { $mountcommand = $mountcommand + ' -nic1internalip ' +$_.nic1internalip } 
                if ($_.nic1externalip) { $mountcommand = $mountcommand + ' -nic1externalip ' +$_.nic1externalip } 
                if ($_.nic2hostproject) { $mountcommand = $mountcommand + ' -nic2hostproject "' +$_.nic2hostproject +'"' }
                if ($_.nic2network) { $mountcommand = $mountcommand + ' -nic2network "' +$_.nic2network +'"'} 
                if ($_.nic2subnet) { $mountcommand = $mountcommand + ' -nic2subnet "' +$_.nic2subnet +'"'} 
                if ($_.nic2internalip) { $mountcommand = $mountcommand + ' -nic2internalip ' +$_.nic2internalip } 
                if ($_.nic2externalip) { $mountcommand = $mountcommand + ' -nic2externalip ' +$_.nic2externalip } 
                if ($_.nic3hostproject) { $mountcommand = $mountcommand + ' -nic3hostproject "' +$_.nic3hostproject +'"' }
                if ($_.nic3network) { $mountcommand = $mountcommand + ' -nic3network "' +$_.nic3network +'"'} 
                if ($_.nic3subnet) { $mountcommand = $mountcommand + ' -nic3subnet "' +$_.nic3subnet +'"'} 
                if ($_.nic3internalip) { $mountcommand = $mountcommand + ' -nic3internalip ' +$_.nic3internalip } 
                if ($_.nic3externalip) { $mountcommand = $mountcommand + ' -nic3externalip ' +$_.nic3externalip } 
                if ($_.poweronvm) { $mountcommand = $mountcommand + ' -poweronvm ' + $_.poweronvm } 
                if ($_.retainlabel) { $mountcommand = $mountcommand + ' -retainlabel ' + $_.retainlabel } 
                $agmip = $using:agmip 
                $AGMSESSIONID = $using:AGMSESSIONID
                $IGNOREAGMCERTS = $using:IGNOREAGMCERTS
                Invoke-Expression $mountcommand 
                Start-Sleep -seconds 15
            } -throttlelimit $limit
        }
    }
    else 
    {
        foreach ($app in $recoverylist)
        {
        
            $mountcommand = 'New-AGMLibGCPInstance -srcid ' +$app.srcid +' -zone ' +$app.zone +' -projectname ' +$app.projectname +' -machinetype ' +$app.machinetype +' -instancename ' +$app.instancename +' -nic0network "' +$app.nic0network +'" -nic0subnet "' +$app.nic0subnet +'"'
            if ($app.nic0hostproject) { $mountcommand = $mountcommand + ' -nic0hostproject "' +$app.nic0hostproject +'"' }
            if ($app.appid) { $mountcommand = $mountcommand + ' -appid "' +$app.appid +'"' }
            if ($app.appname) {  $mountcommand = $mountcommand + ' -appname "' +$app.appname +'"' }
            if ($app.networktags) { $mountcommand = $mountcommand + ' -networktags "' +$app.networktags +'"' } 
            if ($app.serviceaccount) { $mountcommand = $mountcommand + ' -serviceaccount "' +$app.serviceaccount +'"'} 
            if ($app.labels) { $mountcommand = $mountcommand + ' -labels "' +$app.labels +'"' } 
            if ($app.nic0externalip) { $mountcommand = $mountcommand + ' -nic0externalip ' +$app.nic0externalip } 
            if ($app.nic0internalip) { $mountcommand = $mountcommand + ' -nic0internalip ' +$app.nic0internalip } 
            if ($app.nic1hostproject) { $mountcommand = $mountcommand + ' -nic1hostproject "' +$app.nic1hostproject +'"' }
            if ($app.nic1network) { $mountcommand = $mountcommand + ' -nic1network "' +$app.nic1network +'"'} 
            if ($app.nic1subnet) { $mountcommand = $mountcommand + ' -nic1subnet "' +$app.nic1subnet +'"'} 
            if ($app.nic1internalip) { $mountcommand = $mountcommand + ' -nic1internalip ' +$app.nic1internalip } 
            if ($app.nic1externalip) { $mountcommand = $mountcommand + ' -nic1externalip ' +$app.nic1externalip } 
            if ($app.nic2hostproject) { $mountcommand = $mountcommand + ' -nic2hostproject "' +$app.nic2hostproject +'"' }
            if ($app.nic2network) { $mountcommand = $mountcommand + ' -nic2network "' +$app.nic2network +'"'} 
            if ($app.nic2subnet) { $mountcommand = $mountcommand + ' -nic2subnet "' +$app.nic2subnet +'"'} 
            if ($app.nic2internalip) { $mountcommand = $mountcommand + ' -nic2internalip ' +$app.nic2internalip } 
            if ($app.nic2externalip) { $mountcommand = $mountcommand + ' -nic2externalip ' +$app.nic2externalip } 
            if ($app.nic3hostproject) { $mountcommand = $mountcommand + ' -nic3hostproject "' +$app.nic3hostproject +'"' }
            if ($app.nic3network) { $mountcommand = $mountcommand + ' -nic3network "' +$app.nic3network +'"'} 
            if ($app.nic3subnet) { $mountcommand = $mountcommand + ' -nic3subnet "' +$app.nic3subnet +'"'} 
            if ($app.nic3internalip) { $mountcommand = $mountcommand + ' -nic3internalip ' +$app.nic3internalip } 
            if ($app.nic3externalip) { $mountcommand = $mountcommand + ' -nic3externalip ' +$app.nic3externalip } 
            if ($app.poweronvm) { $mountcommand = $mountcommand + ' -poweronvm ' + $app.poweronvm } 
            if ($app.retainlabel) { $mountcommand = $mountcommand + ' -retainlabel ' + $app.retainlabel } 

            $runcommand = Invoke-Expression $mountcommand 
        
            if ($runcommand.errormessage)
            { 
                if ($textoutput)
                {
                    write-host "The following command encountered this error: " $runcommand.errormessage 
                    $mountcommand
                    write-host ""
                }
                else {
                    $printarray += [pscustomobject]@{
                        appname = $app.appname
                        appid = $app.appid
                        instancename = $app.instancename
                        result = "failed"
                        message = $runcommand.errormessage.Trim() 
                        command =  $mountcommand }
                }
            }
            elseif ($runcommand.err_message)
            { 
                if ($textoutput)
                {
                    write-host "The following command encountered this error: " $runcommand.err_message 
                    $mountcommand
                    write-host ""
                }
                else {
                    $printarray += [pscustomobject]@{
                        appname = $app.appname
                        appid = $app.appid
                        instancename = $app.instancename
                        result = "failed"
                        message = $runcommand.err_message.Trim()
                        errorcode = $runcommand.err_code 
                        command =  $mountcommand }
                }
            }
            elseif ($runcommand.jobstatus)
            {
                if ($textoutput)
                {
                    write-host "The following command started this job: " $runcommand.jobstatus
                    $mountcommand 
                    write-host ""
                }
                else 
                {
                    $printarray += [pscustomobject]@{
                        appname = $app.appname
                        appid = $app.appid
                        instancename = $app.instancename
                        result = "started"
                        message = $runcommand.jobstatus 
                        command =  $mountcommand }
                }
            }
            else
            {
                if ($textoutput)
                {
                    write-host "The following command may not have started: " $runcommand
                    $mountcommand 
                    write-host ""
                }
                else {
                    $printarray += [pscustomobject]@{
                        appname = $app.appname
                        appid = $app.appid
                        result = "unknown"
                        command =  $mountcommand }
                }
            }
        }
        
        if (!($textoutput))
        {
            $printarray
        }
    }
    
}