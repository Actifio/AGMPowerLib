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


Function Confirm-AGMLibComputeEngineImage([string]$id,[switch]$every,[string]$appid) 
{
    <#
    .SYNOPSIS
    Confirms that the Compute Engine Snapshot created by a backup image still exists.

    .EXAMPLE
    Confirm-AGMLibComputeEngineImage -id 1234
    Validates backup image ID 1234.   The status field is reported by Compute Engine    If the status does not show as READY you will need to investigate

    .DESCRIPTION
    A function to validate images.  Use this to confirm that an image shown in Backup and DR has all the relevant backing Compute Engine snapshots.
    To find eligible images use filters like:   Get-AGMImage -filtervalue apptype=GCPInstance

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
    
    # we depend on Google Cloud module being present
    try
    {
        Import-Module GoogleCloud -ErrorAction SilentlyContinue
    }

    catch
    {
        $retVal = $false
    }
    $moduletest = get-module -name GoogleCloud 
    if (!($moduletest.Version))
    {
        Get-AGMErrorMessage -messagetoprint "GoogleCloud module was not found using Get-Module command"
        return
    }
    if ((!($id)) -and (!($every)) -and (!($appid)))
    {
        $id = Read-Host "Backup Image ID"
    }
    if ($id) { $imagelist = Get-AGMImage $id }
    if ($every) { $imagelist = Get-AGMImage -filtervalue apptype=GCPInstance}
    if ($appid) { $imagelist = Get-AGMImage -filtervalue appid=$appid }
    if (!($imagelist.id))
    {
        if ($every) { Get-AGMErrorMessage -messagetoprint "Failed to find any images using: Get-AGMImage -filtervalue apptype=GCPInstance" }
        if ($id) { Get-AGMErrorMessage -messagetoprint "Failed to find any images using: Get-AGMImage $id" }
        if ($appid) { Get-AGMErrorMessage -messagetoprint "Failed to find any images using:  Get-AGMImage -filtervalue appid=$appid" }
        return
    }
    foreach ($image in $imagelist)
    {
        $imagegrab = Get-AGMImage $image.id
        $apptype = $imagegrab.apptype
        if ($apptype -ne "GCPInstance")
        {
            Get-AGMErrorMessage -messagetoprint "Apptype $apptype is not the correct apptype.  Expecting Compute Engine Instance apptype: GCPInstance"
            return
        }
        $snapshotlist = $imagegrab.restorableobjects.volumeinfo

        if (!($snapshotlist.target))
        {
            Get-AGMErrorMessage -messagetoprint "Image does not contain volumeinfo that can be used to find Compute Engine Snapshot"
            return
        }
        $projectgrab = $imagegrab.application.host.friendlypath
        if ($projectgrab)
        {
            $projectid = $projectgrab.split(":")[3]
        }

        $AGMArray = @()
        Foreach ($snap in $snapshotlist.target)
        {
            $snapshotname = $snap.split(":")[1]
            Try
            {
                $snapgrab = Get-GceSnapshot -Project $projectid -Name $snapshotname
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError)
            {
                $cleaned = Test-AGMJSON $RestError
                if ($cleaned.errormessage)
                {
                    #Get-AGMErrorMessage -messagetoprint $cleaned.errormessage
                    $AGMArray += [pscustomobject]@{
                        id = $imagegrab.id
                        project = $projectid
                        appliance = $imagegrab.clusterid
                        imagename = $imagegrab.backupname
                        snapshotname = $snapshotname
                        status = $cleaned.errormessage
                    }
                }
                else
                {
                    Get-AGMErrorMessage -messagetoprint $cleaned
                    return
                }
            }
            else 
            {
                #$snapgrab
                $AGMArray += [pscustomobject]@{
                    id = $imagegrab.id
                    project = $projectid
                    appliance = $imagegrab.clusterid
                    imagename = $imagegrab.backupname
                    snapshotname = $snapshotname
                    status = $snapgrab.Status
                }
            }
        }
        $AGMArray
    }
}
