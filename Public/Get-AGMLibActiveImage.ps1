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


Function Get-AGMLibActiveImage([string]$label,[string]$appid,[string]$jobclass,[switch][alias("i")]$imageidprint,[switch][alias("n")]$nfsprint,[switch][alias("u")]$unmount) 
{
    <#
    .SYNOPSIS
    Displays all mounts

    .EXAMPLE
    Get-AGMActiveImages
    Displays all active images (mounts)

    .EXAMPLE
    Get-AGMActiveImages
    Displays all active images (mounts)

    .EXAMPLE
    Get-AGMActiveImages -appid 4771
    Displays all active images for the app with ID 4771

    .DESCRIPTION
    A function to find the active images

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
    
    
    $fv = "characteristic=1&characteristic=2&apptype!nas"
    if ($unmount)
    {
        $fv = "characteristic=2"
    }
    if ($jobclass)
    {
        $fv = $fv + "&jobclass=$jobclass"
    }
    if ($appid) 
    {
        $fv = $fv + "&appid=$id" 
    }
    if ($label)
    {
        $fv = $fv + "&label=$label" 
    }
   
    
    $backup = Get-AGMImage -filtervalue "$fv" 
    if ($backup.id)
    {
        $AGMArray = @()

        Foreach ($id in $backup)
        { 
            $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.cluster.name
            $id | Add-Member -NotePropertyName hostname -NotePropertyValue $id.host.hostname
            $id | Add-Member -NotePropertyName appid -NotePropertyValue $id.application.id
            $id | Add-Member -NotePropertyName mountedhostname -NotePropertyValue $id.mountedhost.hostname
            $id | Add-Member -NotePropertyName childappname -NotePropertyValue $id.childapp.appname
            $startdate=[datetime]$id.modifydate
            $enddate=(GET-DATE)
            $age = NEW-TIMESPAN -Start $StartDate -End $EndDate
            $id | Add-Member -NotePropertyName daysold -NotePropertyValue $age.days 
            if ($id.characteristic -eq "Mount")
            {
                $imagestate = "Mounted"
            }
            else 
            {
                $imagestate = "Unmounted"
            }
            if ( $id.flags_text -contains "JOBFLAGS_MIGRATING")
            {
                $imagestate = "Migrating"
            }
            if (( $id.flags_text -contains "JOBFLAGS_CONTAINER_MOUNT") -and ($id.characteristic -eq "Mount"))
            {
                $imagestate = "mapped"
            }
            if ($imageidprint)
            {
                $AGMArray += [pscustomobject]@{
                    id = $id.id
                    apptype = $id.apptype
                    appliancename = $id.appliancename
                    hostname = $id.hostname
                    appname = $id.appname
                    mountedhost = $id.mountedhostname
                    allowedip = $id.allowedips
                    childappname = $id.childappname
                    consumedsize_gib = [math]::Round($id.consumedsize / 1073741824,3)
                    daysold = $id.daysold
                    label = $id.label
                    imagestate = $imagestate
                }
            }
            elseif ($nfsprint)
            {
                if ($id.allowedips)
                {
                    $AGMArray += [pscustomobject]@{
                        id = $id.id
                        apptype = $id.apptype
                        appliancename = $id.appliancename
                        hostname = $id.hostname
                        appname = $id.appname
                        allowedip = $id.allowedips
                        consumedsize_gib = [math]::Round($id.consumedsize / 1073741824,3)
                        daysold = $id.daysold
                        label = $id.label
                        imagestate = $imagestate
                    }
                }
            }
            else 
            {
                $AGMArray += [pscustomobject]@{
                    id = $id.id
                    imagename = $id.backupname
                    apptype = $id.apptype
                    appliancename = $id.appliancename
                    hostname = $id.hostname
                    appname = $id.appname
                    mountedhost = $id.mountedhostname
                    allowedip = $id.allowedips
                    childappname = $id.childappname
                    consumedsize_gib = [math]::Round($id.consumedsize / 1073741824,3)
                    daysold = $id.daysold
                    label = $id.label
                    imagestate = $imagestate
                }
            }
        }
        $AGMArray  | sort-Object appliancename,hostname,appname
    }
    else
    {
        $backup
    }
}