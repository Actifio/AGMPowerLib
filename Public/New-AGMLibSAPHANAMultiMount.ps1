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


Function New-AGMLibSAPHANAMultiMount ([string]$instancelist,[switch]$textoutput,[decimal]$limit) 
{
    <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of SAP HANA databases to create many new SAP HANA mounts

    .EXAMPLE
    New-AGMLibSAPHANAMultiMount -instancelist recoverylist.csv

    This will load the contents of the file recoverylist.csv and use it to run multiple New-AGMLibSAPHANAMount jobs

    .DESCRIPTION
    This routine needs a well formatted CSV file.    Here is an example of such a file:

    appid,appname,mountapplianceid,imagename,targethostid,dbsid,userstorekey,mountpointperimage,label,recoverypoint,mountmode,mapdiskstoallesxhosts,sltid,slpid
    835132,"act","144091747698","Image_0160795","749871","act","actbackup","/mount","label1","2022-11-07 17:00:39","nfs","false","108758","706611"
 
    If you specify both appname and appid then appid will be used.  The appname is mandatory so you know the name of the source VM.  The imagename field is NOT mandatory.
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
        Get-AGMErrorMessage -messagetoprint "SAP HANA list: $instancelist could not be opened."
        return;
    }

    # first we quality check the CSV
    if ($recoverylist.mountapplianceid -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: mountapplianceid" ;return }
    if ($recoverylist.dbsid -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: dbsid" ;return }
    if ($recoverylist.userstorekey -eq $null) { Get-AGMErrorMessage -messagetoprint "The following mandatory column is missing: userstorekey" ;return }
    if (($recoverylist.appname -eq $null) -and ($recoverylist.appid -eq $null))  {  Get-AGMErrorMessage -messagetoprint "Could not find either appid or appname columns" ; return }

    # dry run for srcid and appname
    $row =1
    foreach ($app in $recoverylist)
    {
        if ($app.mountapplianceid -eq "") { write-host  "The following mandatory value is missing: mountapplianceid in row $row" ; return }
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
                $mountcommand = 'New-AGMLibSAPHANAMount -mountapplianceid ' +$_.mountapplianceid +' -targethostid ' +$_.targethostid +' -dbsid ' +$_.dbsid +' -userstorekey ' +$_.userstorekey +' -mountpointperimage ' +$_.mountpointperimage 
                if ($_.appid) { $mountcommand = $mountcommand + ' -appid "' +$_.appid +'"' }
                if ($_.appname) {  $mountcommand = $mountcommand + ' -appname "' +$_.appname +'"' }
                if ($_.imagename) { $mountcommand = $mountcommand + ' -imagename "' +$_.imagename +'"' } 
                if ($_.label) { $mountcommand = $mountcommand + ' -label "' +$_.label +'"'} 
                if ($_.recoverypoint) { $mountcommand = $mountcommand + ' -recoverypoint "' +$_.recoverypoint +'"' } 
                if ($_.mountmode) { $mountcommand = $mountcommand + ' -mountmode ' +$_.mountmode } 
                if ($_.mapdiskstoallesxhosts) { $mountcommand = $mountcommand + ' -mapdiskstoallesxhosts ' +$_.mapdiskstoallesxhosts } 
                if ($_.sltid) { $mountcommand = $mountcommand + ' -sltid "' +$_.sltid +'"' }
                if ($_.slpid) { $mountcommand = $mountcommand + ' -slpid "' +$_.slpid +'"'} 
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
                $mountcommand = 'New-AGMLibSAPHANAMount -mountapplianceid ' +$_.mountapplianceid +' -targethostid ' +$_.targethostid +' -dbsid ' +$_.dbsid +' -userstorekey ' +$_.userstorekey +' -mountpointperimage ' +$_.mountpointperimage
                if ($_.appid) { $mountcommand = $mountcommand + ' -appid "' +$_.appid +'"' }
                if ($_.appname) {  $mountcommand = $mountcommand + ' -appname "' +$_.appname +'"' }
                if ($_.imagename) { $mountcommand = $mountcommand + ' -imagename "' +$_.imagename +'"' } 
                if ($_.label) { $mountcommand = $mountcommand + ' -label "' +$_.label +'"'} 
                if ($_.recoverypoint) { $mountcommand = $mountcommand + ' -recoverypoint "' +$_.recoverypoint +'"' } 
                if ($_.mountmode) { $mountcommand = $mountcommand + ' -mountmode ' +$_.mountmode } 
                if ($_.mapdiskstoallesxhosts) { $mountcommand = $mountcommand + ' -mapdiskstoallesxhosts ' +$_.mapdiskstoallesxhosts } 
                if ($_.sltid) { $mountcommand = $mountcommand + ' -sltid "' +$_.sltid +'"' }
                if ($_.slpid) { $mountcommand = $mountcommand + ' -slpid "' +$_.slpid +'"'} 
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
        
            $mountcommand = 'New-AGMLibSAPHANAMount -mountapplianceid ' +$_.mountapplianceid +' -targethostid ' +$_.targethostid +' -dbsid ' +$_.dbsid +' -userstorekey ' +$_.userstorekey +' -mountpointperimage ' +$_.mountpointperimage
            if ($_.appid) { $mountcommand = $mountcommand + ' -appid "' +$_.appid +'"' }
            if ($_.appname) {  $mountcommand = $mountcommand + ' -appname "' +$_.appname +'"' }
            if ($_.imagename) { $mountcommand = $mountcommand + ' -imagename "' +$_.imagename +'"' } 
            if ($_.label) { $mountcommand = $mountcommand + ' -label "' +$_.label +'"'} 
            if ($_.recoverypoint) { $mountcommand = $mountcommand + ' -recoverypoint "' +$_.recoverypoint +'"' } 
            if ($_.mountmode) { $mountcommand = $mountcommand + ' -mountmode ' +$_.mountmode } 
            if ($_.mapdiskstoallesxhosts) { $mountcommand = $mountcommand + ' -mapdiskstoallesxhosts ' +$_.mapdiskstoallesxhosts } 
            if ($_.sltid) { $mountcommand = $mountcommand + ' -sltid "' +$_.sltid +'"' }
            if ($_.slpid) { $mountcommand = $mountcommand + ' -slpid "' +$_.slpid +'"'} 

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