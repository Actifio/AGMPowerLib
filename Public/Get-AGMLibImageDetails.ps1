
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

Function Get-AGMLibImageDetails ([string]$appid) 
{
    <#
    .SYNOPSIS
    Displays the images for a specified app

    .EXAMPLE
    Get-AGMDBMImageDetails
    You will be prompted for App ID

    .EXAMPLE
    Get-AGMDBMImageDetails 2133445
    Display images for AppID 2133445


    .DESCRIPTION
    A function to find images for a nominated app and show some interesting fields

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
    
    
    if (!($appid))
    {
        [string]$appid = Read-Host "AppID"
    }
         
    $output = Get-AGMImage -filtervalue appid=$appid -sort "jobclasscode:asc,consistencydate:asc"
    if ($output.id)
    {
        $backup = Foreach ($id in $output)
        { 
            $id | select-object backupname, jobclass, consistencydate, endpit 
        }
        $backup
    }
    else
    {
        $output
    }
}