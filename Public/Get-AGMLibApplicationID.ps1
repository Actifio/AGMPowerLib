
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

Function Get-AGMLibApplicationID ([string]$appname,[switch][alias("f")]$fuzzy,[string]$friendlytype,[string]$apptype,[string]$appliancename,[string]$applianceid,[string]$filtervalue,[string]$hostname,[string]$hostid) 
{
    <#
    .SYNOPSIS
    Displays the App IDs for a nominated AppName.

    .EXAMPLE
    Get-AGMLibApplicationID
    You will be prompted for AppName

    .EXAMPLE
    Get-AGMLibApplicationID smalldb
    To search for the AppID of any apps called smalldb

    .EXAMPLE
    Get-AGMLibApplicationID smalldb -f
    To search for the AppID of any apps with a name like smalldb.   The -f is for fuzzy search

    .DESCRIPTION
    A function to find any Apps with nominated name

    There are seven extra search options apart from appname, which is mandatory
    Type of App:
    -apptype xxxx  To also search by apptype such as -apptype SqlInstance
    -friendlytype xxxx  To also search by friendlytype such as -friendlytype SqlInstance

    Appliance:
    -applianceid  xxxx  To also search by applianceID such as -applianceid 1415071155
    -appliancename xxxx  To also search by appliancename such as -appliancename sydactsky1

    Host: 
    -hostid xxxx   To also search by hostid such as -hostid 655173
    -hostname xxxx   To also search by hostname such as -hostname sydwinsqlc2

    Finally you can specify -filtervalue to add your own filters.
    You can use any filter shown by this command:
    Get-AGMApplication -o

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
    

    # we expect appname as a minimum
    if (!($appname))
    {
        $appname = Read-Host "AppName"
    }
    # fv always starts with appname
    $fv = "appname=$appname"
     # if they asked for fuzzy
     if ($fuzzy)
     {
        $fv = "appname~$appname"
     }
     # if user specified filtervalue lets use it
    if ($filtervalue)
    {
        $fv = $fv + "&" + "$filtervalue"
    }   
    # if user specified friendlytype lets use it
    if ($friendlytype)
    {
        $fv = $fv + "&" +"friendlytype=$friendlytype"
    } 
    # if user specified apptype lets use it
    if ($apptype)
    {
        $fv = $fv + "&" +"apptype=$apptype"
    }     
    # if user specified appliancename lets use it
    if ($appliancename)
    {
        $fv = $fv + "&" +"appliancename=$appliancename"
    }  
    # if user specified applianceid lets use it
    if ($applianceid)
    {
        $fv = $fv + "&" + "clusterid=$applianceid"
    }  
    # if user specified hostname lets use it
    if ($hostname)
    {
        $fv = $fv + "&" + "hostname=$hostname"
    }  

    # if user specified hostid lets use it
    if ($hostid)
    {
        $fv = $fv + "&" + "hostid=$hostid"
    }  

    # lets get the output
    $output = Get-AGMApplication -filtervalue $fv

    if ($output.id)
    {
        $AGMArray = @()

        Foreach ($id in $output)
        { 
            $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.cluster.name
            $id | Add-Member -NotePropertyName applianceip -NotePropertyValue $id.cluster.ipaddress
            $id | Add-Member -NotePropertyName appliancetype -NotePropertyValue $id.cluster.type
            $id | Add-Member -NotePropertyName applianceid -NotePropertyValue $id.cluster.clusterid
            $id | Add-Member -NotePropertyName hostname -NotePropertyValue $id.host.hostname
            $id | Add-Member -NotePropertyName hostid -NotePropertyValue $id.host.id
            $id | Add-Member -NotePropertyName slaid -NotePropertyValue $id.sla.id
            if ($id.hostname)
            {
                $AGMArray += [pscustomobject]@{
                    id = $id.id
                    friendlytype = $id.friendlytype
                    hostname = $id.hostname
                    hostid = $id.hostid
                    appname = $id.appname
                    appliancename = $id.appliancename
                    applianceip = $id.applianceip
                    applianceid = $id.applianceid
                    appliancetype = $id.appliancetype
                    managed = $id.managed
                    slaid = $id.slaid
                }
            }
        }
        $AGMArray | Sort-Object -Property hostname -Descending
    }
    else
    {
        $output
    }
}
