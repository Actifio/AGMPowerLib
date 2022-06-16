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


Function Set-AGMLibImage ([array]$imagelist,$filename,[string]$imagename,[string]$label) 
{
    <#
    .SYNOPSIS
    Sets the label for an image or a range of images using either an array of images or a CSV file

    .EXAMPLE
    Set-AGMLibImage -imagename Image_1234 -label "ConfirmedGood" 
    Set the label for the image with imagename Image_1234

    .EXAMPLE
    Set-AGMLibImage -imagelist $imagelist 
    Uses the $imagelist variable that you need to create beforehand that lists imagname, image ID and new label and sets the label specified for each image

    .EXAMPLE
    Set-AGMLibImage -filename fileofimages.csv
    Loads the CSV file fileofimages.csv and then for each image in the file, sets the label specified for that image in that file

    .DESCRIPTION
    We can create an imagelist several ways.   This method literally gets every image
    $imagelist = Get-AGMImage | select id,backupname,label
    We could update the label field like this:
       foreach ($image in $imagelist) { $image.label = "Needs Checking" }
    Then run the command:   Set-AGMLibImage -imagelist $imagelist 
    We could then export  like this:    $imagelist | Export-Csv -Path images.csv
    Then edit the file and when reading save the CSV and run this command:  
    Set-AGMLibImage -filename images.csv

    Another way to create the image list is with:   New-AGMLibImageRange


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
    
    if ((!($imagelist)) -and (!($filename)) -and (!($imagename)))
    {
        Write-host "This function is used to label a large number of images in a single command.  This is done by supplying one of the following:
-- A list of images to label, normally created with New-AGMLibImageRange.  We then use:   Set-AGMLibImage -imagelist <imagelist>
-- A CSV file contained a list of images with new labels.  The file needs to have at least id,backupname,label as headings.  You could use New-AGMLibImageRange to create this file.  Then use:  Set-AGMLibImage -filename <filename.csv>
-- An imagename.   You could learn this in the AGM Web GUI.   Then use:  Set-AGMLibImage -imagename <imagename> -label <newlabel>"
    }
    if ($filename)
    {
        if ([IO.File]::Exists($filename))
        {
            $imagelist = Import-Csv -Path $filename
        }
    }
    if ($imagelist)
    {
        if ((!($imagelist.id)) -or (!($imagelist.label)) -or (!($imagelist.backupname)))
        {
            Get-AGMErrorMessage -messagetoprint "The imagelist specified with -imagelist needs to contain the following fields:  id, backupname, label"
            return
        }
    }
    if ($imagename)
    {
        if (!($label))
        {
            [string]$label = Read-host "Label"
        }
        Set-AGMImage -imagename $imagename -label $label
    }
    else {
        foreach ($image in $imagelist | where-object {$_.label.length -gt 0})
        {
            Set-AGMImage -id $image.id -label $image.label -imagename $image.backupname
        }
    }
}
