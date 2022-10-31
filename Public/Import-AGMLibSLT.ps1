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


Function Import-AGMLibSLT([string]$filename,[string]$bucket,[string]$objectname) 
{
    <#
    .SYNOPSIS
    Imports Policy Templates

    .EXAMPLE
    Import-AGMLibSLT -filename outfile.json
    Imports all SLTs from a file called outfile.json

    .EXAMPLE
    Import-AGMLibSLT -bucket avwlab2testbucket -objectname itsthename.json1
    Imports the contents of a JSON file in a GCS bucket.   
    This presumes the Google Cloud Tools for PowerShell Module has been installed and that the user has access to the bucket

    .DESCRIPTION
    A function to import Policy Templates

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
    
    if ($bucket) 
    {
        if (!($objectname))
        {
            $objectname = Read-host "Please supply the object name in GCS of the exported templates"
        }
        if ($objectname)
        {
            $json = Read-GcsObject -bucket $bucket -objectname $objectname
        }
        if ($json)
        {
            Post-AGMAPIData  -endpoint /slt/import -body $json
        }
        return
    }


    if (!($filename))
    {
        $filename = Read-host "Please supply the filename of the exported templates"
    }
    if ( Test-Path $filename )
    {
        $json = Get-Content -Path $filename
    }
    else
    {
        Get-AGMErrorMessage -messagetoprint "The file named $filename could not be found."
        return
    }
    Post-AGMAPIData  -endpoint /slt/import -body $json
}
