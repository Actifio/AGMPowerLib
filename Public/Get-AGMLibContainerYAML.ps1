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


Function Get-AGMLibContainerYAML ([string]$imagename)
{
    <#
    .SYNOPSIS
    Displays the YAML for a container mount

    .EXAMPLE
    Get-AGMLibContainerYAML 
    You will be prompted for ImageID

    .EXAMPLE
    Get-AGMLibContainerYAML 54433520
    To display the YAML for Image 54433520

    .EXAMPLE
    Get-AGMLibContainerYAML 54433520
    To display the YAML for Image 54433520

    .EXAMPLE
    Get-AGMLibContainerYAML -imagename Image_25355628
    To display the YAML for Image_25355628

    .DESCRIPTION
    A function to display the YAML for a container mount

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
    

    if ($imagename)
    {
        $imageidgrab = Get-AGMImage -filtervalue backupname=$imagename 
        if ($imageidgrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Could not determine an image ID for $imagename"
            return
        }
        else 
        {
            $imageid = ($imageidgrab).id
        }
    }

    if (!($imageid))
    {
        $imageid = Read-host "Image ID"
    }

    $yamlgrab = (Get-AGMImage -id $imageid).yaml
    $yamlgrab
    
}
