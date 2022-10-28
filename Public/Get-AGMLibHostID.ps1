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


Function Get-AGMLibHostID ([string]$hostname) 
{
    <#
    .SYNOPSIS
    Displays the Host IDs for a nominated HostName.

    .EXAMPLE
    Get-AGMDBMHostID
    You will be prompted for HostName

    .EXAMPLE
    Get-AGMDBMHostID smalldb
    To search for the HostID of any hosts called smalldb

    .DESCRIPTION
    A function to find any Hosts with nominated HostName

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
    
    if (!($hostname))
    {
        $hostname = Read-Host "HostName"
    }
         
    $output = Get-AGMHost -filtervalue hostname~$hostname
    if ($output.id)
    {
        $AGMArray = @()

        Foreach ($id in $output)
        { 
            $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.appliance.name
            $id | Add-Member -NotePropertyName applianceip -NotePropertyValue $id.appliance.ipaddress
            $id | Add-Member -NotePropertyName appliancetype -NotePropertyValue $id.appliance.type
            $AGMArray += [pscustomobject]@{
                id = $id.id
                hostname = $id.hostname
                osrelease = $id.osrelease
                appliancename = $id.appliancename
                applianceip = $id.applianceip
                appliancetype = $id.appliancetype
            }
        }
        $AGMArray | Sort-Object -Property hostname -Descending
    }
    else
    {
        $output
    }
}
