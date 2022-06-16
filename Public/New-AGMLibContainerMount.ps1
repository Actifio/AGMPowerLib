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


Function New-AGMLibContainerMount ([string]$appid,[string]$appname,[string]$allowedips,[string]$imageid,[string]$imagename,[string]$label,[string]$volumes,[switch][alias("g")]$guided) 
{
    <#
    .SYNOPSIS
    Mounts an image to a container

    .EXAMPLE
    New-AGMLibContainerMount 

    Runs a guided menu to mount an image to a container

    .EXAMPLE
    New-AGMLibVMExisting -imageid 54380607 -volumes "dasvol:/dev/hanavg/log;/tmp/cmounts/test1;/custmnt2,dasvol:/dev/hanavg/data;/tmp/cmounts/test2;/ss" -allowedips "1.1.1.1,10.10.10.10"

    Mounts Image ID 54380607
    The -volumes list each moint point in the image.  Each mount point is comma separated
    For each each mountpoint we need three values, that are semi-colon separated
    In this example, there are two mount points, the first one is /dev/hanavg/log.
    It is given an appliance mountpoint of /test1 and an NFS export path of /custmnt2

    The allowedips is a comma separated list of IP addresses that can connect to the appliance mountpoint.

    .DESCRIPTION
    A function to mount images to containers

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



    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $true
        $appname = read-host "Which appname do you want to work with"
    }
    

    # if we got a VMware appname lets check it right now
    if ( ($appname) -and (!($appid)) )
    {
        $appgrab = Get-AGMApplication -filtervalue "appname=$appname"
        if ($appgrab.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appname to a unique valid app.  Use Get-AGMLibApplicationID and try again specifying -appid."
            return
        }
        else {
            $appid = $appgrab.id
        }
    }

    # if the user didn't specify a target we need to ask for one now
    if (!($allowedips)) 
    {
        [string]$allowedips = Read-Host "Allowed IP addresses (comma separated list)"
    }    

    # learn about the image if the user gave it
    if ($imagename)
    {
        $imagegrab = Get-AGMImage -filtervalue backupname=$imagename
        if (!($imagegrab))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imagename using:  Get-AGMImage -filtervalue backupname=$imagename"
            return
        }
        else 
        {
            $imageid = $imagegrab.id
        }
    }

    # finally if the user gave an AppID lets check it
    if ($appid)
    {
        $imagegrab = Get-AGMLibLatestImage $appid
        if (!($imagegrab.backupname))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find snapshot for AppID using:  Get-AGMLatestImage $appid"
            return
        }   
        else 
        {
            $imagename = $imagegrab.backupname
            $imageid = $imagegrab.id
        }
    }

    # this if for guided menu
    if ($guided)
    {
        if (!($label))
        {
            Clear-Host
            [string]$label = Read-host "Label"
        }

        $imagegrab = Get-AGMimage -id $imageid 
        $vollist = $imagegrab.restorableobjects 
    
        if (!($vollist))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any volumes"
            return
        }
        if ($vollist.volumeinfo.count -eq 1) 
        {
            $uniqueid = $imagegrab.restorableobjects.volumeinfo.uniqueid
            $logicalname = $imagegrab.restorableobjects.volumeinfo.logicalname
            $appliancemountpoint = Read-Host "Appliance mount point for $logicalname"
            $mountpoint = Read-Host "NFS Export Path for $logicalname"
            if ($appliancemountpoint)
            {
                if ($appliancemountpoint.substring(0,1) -ne "/")
                {
                    $appliancemountpoint = "/tmp/cmounts/" + $appliancemountpoint
                }
                else {
                    $appliancemountpoint = "/tmp/cmounts" + $appliancemountpoint
                }
            }
            $volumes = $uniqueid + ";" + "$appliancemountpoint" + ";" + $mountpoint
        }
        else
        {
            
            foreach ($point in $vollist.volumeinfo)
            { 
                $uniqueid = $point.uniqueid
                $logicalname = $point.logicalname
                $appliancemountpoint = Read-Host "Appliance mount point for $logicalname"
                $mountpoint = Read-Host "NFS Export Path for $logicalname"
                write-host ""
                if ($appliancemountpoint)
                {
                    if ($appliancemountpoint.substring(0,1) -ne "/")
                    {
                        $appliancemountpoint = "/tmp/cmounts/" + $appliancemountpoint
                    }
                    else {
                        $appliancemountpoint = "/tmp/cmounts" + $appliancemountpoint
                    }
                }
                $volumes = $volumes + "," + $uniqueid + ";" + "$appliancemountpoint" + ";" + $mountpoint
            }
            $volumes = $volumes.substring(1)
            
        }

        Clear-Host
        Write-Host "Guided selection is complete.  The values entered would result in the following command:"
        Write-Host ""
        Write-Host -nonewline "New-AGMLibVMExisting -imageid $imageid -volumes `"$volumes`""
        if ($allowedips)
        {
            Write-Host -nonewline " -allowedips `"$allowedips`""
        }
        Write-Host ""
        Write-Host "1`: Run the command now (default)"
        Write-Host "2`: Show the JSON used to run this command, but don't run it"
        Write-Host "3`: Exit without running the command"
        $userchoice = Read-Host "Please select from this list (1-3)"
        if ($userchoice -eq 2)
        {
            $jsonprint = "yes"
        }
        if ($userchoice -eq 3)
        {
            return
        }
    }


    
    if (!($imageid))
    {
        [string]$imageid = Read-Host "ImageID to mount"
    }


    $selectedobjects = @(
        [pscustomobject]@{restorableobject=$appname}
    )



    if ($volumes)
    {
        $restoreobjectmappings =@(
        foreach ($vol in $volumes.Split(","))
        {
            [ordered]@{
                'restoreobject' = $vol.split(";")[0]
                'appliancemountpoint' = $vol.split(";")[1]
                'mountpoint' = $vol.split(";")[2]
            }
        }
        )
    }

    if (!($label))
    {
        $label = ""
    }

    $body = [ordered]@{
        label = $label;
        container = "true";
        selectedobjects = $selectedobjects;
        restoreobjectmappings = $restoreobjectmappings
    }

    if ($allowedips)
    {
        $allowediplist = @(foreach ($ip in $allowedips.Split(","))
        {
            $ip
        }
        )
        $body = $body + [ordered]@{ allowedips = $allowediplist }
    }

    $json = $body | ConvertTo-Json

    if ($jsonprint -eq "yes")
    {
        $compressedjson = $body | ConvertTo-Json -compress
        Write-host "This is the final command:"
        Write-host ""
        Write-host "Post-AGMAPIData  -endpoint /backup/$imageid/mount -body `'$compressedjson`'"
        return
    }

    Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json
}
