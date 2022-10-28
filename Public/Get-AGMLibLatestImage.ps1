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


Function Get-AGMLibLatestImage([string]$id,[string]$appid,[string]$jobclass) 
{
    <#
    .SYNOPSIS
    Displays the most recent image for an application

    .EXAMPLE
    Get-AGMLatestImage
    You will be prompted for application ID 

    .EXAMPLE
    Get-AGMLatestImage -id 4771
    Get the last snapshot created for the application with ID 4771

    .EXAMPLE
    Get-AGMLatestImage -id 4771 -jobclass dedup
    Get the last dedup created for the application with ID 4771


    .DESCRIPTION
    A function to find the latest image created for an application
    By default you will get the latest snapshot image

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
    
    if ($appid)
    {
        $id = $appid
    }

    if (!($id))
    {
        [string]$id = Read-Host "ID"
    }
      
    if ($jobclass)
    {
        $fv = "appid=" + $id + "&jobclass=$jobclass"
    }
    else 
    {
        $fv = "appid=" + $id + "&jobclass=snapshot"
    }
    
    $backup = Get-AGMImage -filtervalue "$fv" -sort ConsistencyDate:desc -limit 1
    if ($backup.id)
    {
        $backup | Add-Member -NotePropertyName appid -NotePropertyValue $backup.application.id
        $backup | Add-Member -NotePropertyName appliance -NotePropertyValue $backup.cluster.name
        $backup | Add-Member -NotePropertyName hostname -NotePropertyValue $backup.host.hostname
        $backup | Select-Object appliance, hostname, appname, appid, jobclass, backupname, id, consistencydate, endpit, sltname, slpname, policyname
    }
    else
    {
        $backup
    }
}