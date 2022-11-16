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


Function Get-AGMLibLastPostCommand([string]$username,[int]$limit,[switch][alias("d")]$delete,[switch][alias("p")]$put) 
{
    <#
    .SYNOPSIS
    Gets the last POST command issued by a nominated user

    .EXAMPLE
    Get-AGMLibLastPostCommand
    You will be prompted for a username

    .EXAMPLE
    Get-AGMLibLastPostCommand av
    Get the last post command issued by the user called av

    .EXAMPLE
    Get-AGMLibLastPostCommand av 2
    Get the last two post commands issued by the user called av

    .EXAMPLE
    Get-AGMLibLastPostCommand -username av -limit 2 -put
    Get the last two put commands issued by the user called av

    .DESCRIPTION
    A function to get the audit log for the last command you ran

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

    if (!($username))
    {
        $username = Read-Host "UserName"
    }

    if (!($limit))
    {
        $limit = 1
    }

    if ($put)
    {
        Get-AGMAudit -filtervalue "username=$username&command~PUT http" -limit $limit -sort id:desc
    }
    elseif ($delete)
    {
        Get-AGMAudit -filtervalue "username=$username&command~DELETE http" -limit $limit -sort id:desc 
    }
    else
    {
        Get-AGMAudit -filtervalue "username=$username&command~POST http" -limit $limit -sort id:desc 
    }
    
}