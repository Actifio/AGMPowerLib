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


Function New-AGMLibLVMMount ([string]$appid,[string]$mountapplianceid,[string]$appname,[string]$targethostname,[string]$targethostid,[string]$imageid,[string]$imagename,[string]$label,[string]$mountmode,[string]$mountaction,[string]$prescript,[string]$postscript,[string]$volumes,[string]$volumemappings,[string]$mapdiskstoallesxhosts,[string]$mountlocation,[switch][alias("g")]$guided,[switch][alias("m")]$monitor,[switch][alias("w")]$wait) 
{
    <#
    .SYNOPSIS
    Mounts a LVM image

    .EXAMPLE
    New-AGMLibLVMMount 

    Runs a guided menu to mount an image of a LVM to a host

    .EXAMPLE
    New-AGMLibLVMMount -appid 1425738 -targethostid 1425591  -mountaction specifymountlocation -mountapplianceid 145666187717 -mountlocation "/mnt12"

    Mounts the latest image for appid 1425738 on appliance 145666187717 to target host id 1425591, mounting into mount point /mnt12

    .DESCRIPTION
    A function to mount LVM images to an existing host

    * Image selection can be done three ways:

    1)  Run this command in guided mode to learn the available images and select one
    2)  Learn the imagename and specify that as part of the command with -imagename
    3)  Learn the Appid and Cluster ID for the appliance that will mount the image and then use -appid and -mountapplianceid 
    This will use the latest snapshot, StreamSnap or OnVault image on that appliance

    The mount action field is used to determine which mount action to take:
    -mountaction agentmanaged          Will mount using the mount points selected by the agent (this is the default behaviour)
    -mountaction  specifymountlocation    Will mount using the source paths using a specified mount point that is supplied with -mountlocation
    -mountaction nomap                    Will mount without mapping the drives

    There are two monitoring options:

    -wait     This will wait up to 2 minutes for the job to start, checking every 15 seconds to show you the job name
    -monitor  Same as -wait but will also run Get-AGMLibFollowJobStatus to monitor the job to completion
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

    # if the user gave an AppID lets check it and grab an image, need to expand outside snapshots
    if (($appid) -and ($mountapplianceid) -and (!($imageid)))
    {
        # if we are not running guided mode but we have an appid without imageid, then lets get the latest image on the mountappliance ID
        $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:asc" -limit 1
        if ($imagegrab.count -eq 1)
        {   
            $imageid = $imagegrab.id
            $imagename = $imagegrab.backupname
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot, StreamSnap or OnVault Image for appid $appid on appliance with clusterID $mountapplianceid"
            return
        }
    }

    if (($appname) -and (!($appid)) )
    {
        $appgrab = Get-AGMApplication -filtervalue appname=$appname
        if ($appgrab.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appname to a single App ID.  Use Get-AGMLibApplicationID and try again specifying -appid."
            return
        }
        else {
            $appid = $appgrab.id
        }
    }

    # learn about the image
    if ($imagename)
    {
        $imagecheck = Get-AGMImage -filtervalue backupname=$imagename
        if (!($imagecheck))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imagename using:  Get-AGMImage -filtervalue backupname=$imagename"
            return
        }
        else 
        {
            $imagegrab = Get-AGMImage -id $imagecheck.id
            $imageid = $imagegrab.id
            $appname = $imagegrab.appname
            $appid = $imagegrab.application.id
        }
    }


    # if the user gave us nothing to start work, then ask for a VMware VM name
    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $true
        Clear-Host
        Write-host "LVM source selection menu"
        Write-host ""
        $appgrab = Get-AGMApplication -filtervalue "apptype=LVM Volume" | sort-object apptype,appname
        if ($appgrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "There are no LVM apps to list"
            return
        }
        else 
        {
            $i = 1
            foreach ($app in $appgrab)
            { 
            $app | Add-Member -NotePropertyName select -NotePropertyValue $i
            $app | Add-Member -NotePropertyName appliancename -NotePropertyValue $app.cluster.name
            $app | Add-Member -NotePropertyName hostname -NotePropertyValue $app.host.name
            $i++
            }
            Clear-Host
            write-host "Select an application"
            Write-host ""
            $appgrab | select-object select,apptype,hostname,appname,id,appliancename | Format-table *
            While ($true) 
            {
                Write-host ""
                $listmax = $appgrab.id.count
                [int]$userselection = Read-Host "Please select an app to work with (1-$listmax)"
                if ($userselection -lt 1 -or $userselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            if ($appgrab.count -eq 1)
            {
                $appname =  $appgrab.appname
                $appid = $appgrab.id
            }
            else
            {
                $appid = $appgrab.id[($userselection - 1)]
                $appname =  $appgrab.appname[($userselection - 1)]
            }
        }
        
        #image selection time
        Clear-Host
        $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault"  | Sort-Object consistencydate,jobclasscode | select-object -Property backupname,consistencydate,id,jobclass,cluster,transport
        if ($imagelist.backupname.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any snapshot, streamsnap or onvault Images for appid $appid"
            return
        }
        if ($imagelist.backupname.count -eq 1)
        {
            $imagegrab = Get-AGMImage -id ($imagelist).id
            $imagename = $imagegrab.backupname                
            $restorableobjects = $imagegrab.restorableobjects
        } 
        else
        {
            Clear-Host
            Write-Host "Image list.  Choose the best consistency date and jobclass."
            $i = 1
            foreach ($image in $imagelist)
            { 
                $image | Add-Member -NotePropertyName select -NotePropertyValue $i
                $image | Add-Member -NotePropertyName appliancename -NotePropertyValue $image.cluster.name
                $i++
            }

            $imagelist | select-object select,consistencydate,jobclass,appliancename,backupname,id,transport | Format-table *
            While ($true) 
            {
                Write-host ""
                $listmax = $imagelist.Length
                [int]$imageselection = Read-Host "Please select an image (1-$listmax)"
                if ($imageselection -lt 1 -or $imageselection -gt $imagelist.Length)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($imagelist.Length)]"
                } 
                else
                {
                    break
                }
            }
            $imageid =  $imagelist[($imageselection - 1)].id
            $imagegrab = Get-AGMImage -id $imageid
            $imagename = $imagegrab.backupname                
            $restorableobjects = $imagegrab.restorableobjects
            $mountapplianceid = $imagegrab.cluster.clusterid
            $mountappliancename = $imagegrab.cluster.name
        }
    }

    if ( ($targethostname) -and (!($targethostid)) )
    {
        $hostcheck = Get-AGMHost -filtervalue hostname=$targethostname
        if ($hostcheck.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $targethostname to a single host ID.  Use Get-AGMLibHostID and try again specifying -targethostid"
            return
        }
        else 
        {
            $hostgrab = Get-AGMHost -id $hostcheck.id
            $targethostid = $hostgrab.id
            $vmtype = $hostgrab.vmtype
            $transport = $hostgrab.transport
            $diskpref = $hostgrab.diskpref
            $vcenterid = $hostgrab.vcenterhost.id
            #if the VM doesn't have a transport, then the vCenter must have one
            if ( ($vmtype -eq "vmware") -and (!($transport)) )
            {
                $vcgrab = Get-AGMHost -filtervalue id=$vcenterid 
                $transport = $vcgrab.transport
            }
        }
    }

    # if we got a target ID lets check it
    if ( ($targethostid) -and (!($targethostname)) )
    {
        $hostgrab = Get-AGMHost -filtervalue id=$targethostid
        if ($hostgrab.id.count -eq -0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $targethostid to a single host ID.  Use Get-AGMLibHostID and try again specifying -targethostid"
            return
        }
        $targethostname=$hostgrab.hostname
        $vmtype = $hostgrab.vmtype
        $transport = $hostgrab.transport
        $diskpref = $hostgrab.diskpref
        $vcenterid = $hostgrab.vcenterhost.id
        if ( ($vmtype -eq "vmware") -and (!($transport)) )
        {
            $vcgrab = Get-AGMHost -filtervalue id=$vcenterid 
            $transport = $vcgrab.transport
        }
    }
    
    # Guided menu for target selection and moint points and restore points and VMware options
    if ($guided)
    {
        if (!($label))
        {
            Clear-Host
            [string]$label = Read-host "Label"
        }

        # mountedhost menu
        if (!($targethostid))
        {
            $hostgrab = Get-AGMHost -filtervalue "clusterid=$mountapplianceid&hosttype!VMCluster&hosttype!esxhost&hosttype!NetApp 7 Mode&hosttype!NetApp SVM&hosttype!ProxyNASBackupHost&hosttype!Isilon" | sort-object vmtype,hostname
            if ($hostgrab.id.count -eq -0)
            {
                Get-AGMErrorMessage -messagetoprint "Failed to find any hosts on $mountappliancename"
                return
            }
            if ($hostgrab.id.count -eq 1)
            {
                $targethostid = $hostgrab.id
                $targethostname = $hostgrab.hostname
            } 
            else
            {
                Clear-Host
                Write-Host "Host List."
                $i = 1
                foreach ($hostid in $hostgrab)
                { 
                    $hostid | Add-Member -NotePropertyName select -NotePropertyValue $i
                    if (!($hostid.vmtype))
                    {
                        $hostid | Add-Member -NotePropertyName vmtype -NotePropertyValue "Physical"
                    }
                    $i++
                }

                $hostgrab | select-object select,vmtype,hostname,ostype,id | Format-table *
                While ($true) 
                {
                    Write-host ""
                    $listmax = $hostgrab.count
                    [int]$userselection = Read-Host "Please select a host (1-$listmax)"
                    if ($userselection -lt 1 -or $userselection -gt $hostgrab.Length)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$($hostgrab.count)]"
                    } 
                    else
                    {
                        break
                    }
                }
                $targethostid = $hostgrab.id[($userselection - 1)]
                $targethostname = $hostgrab.hostname[($userselection - 1)]
                $vmtype = $hostgrab.vmtype[($userselection - 1)]
                $transport = $hostgrab.transport[($userselection - 1)]
                $diskpref = $hostgrab.diskpref[($userselection - 1)]
                $vcenterid = $hostgrab.vcenterhostid[($userselection - 1)]
                if ( ($vmtype -eq "vmware") -and (!($transport)) )
                {
                    $vcgrab = Get-AGMHost -filtervalue id=$vcenterid 
                    $transport = $vcgrab.transport
                }
            }
        }
        # scripts
        if (!($prescript))
        {
            [string]$prescript = Read-host "Pre-script path (optional, press enter to skip)"
        }
        if (!($postscript))
        {
            [string]$postscript = Read-host "Post-script path (optional, press enter to skip)"
        }




         # if this is a VMTarget
         if ($vmtype -eq "vmware")
         {
             if (($diskpref -eq "BLOCK") -and ($transport -ne "GUESTVMISCSI"))
             {
                 Clear-Host
                 Write-Host "Mount mode" 
                 if ($transport -eq "NFS")
                 {
                     $defaultmode = 3
                     Write-Host "1`: vrdm"
                     Write-Host "2`: prdm"
                     Write-Host "3`: nfs(default)"
                 }
                 else 
                 {
                     $defaultmode = 1
                     Write-Host "1`: vrdm(default)"
                     Write-Host "2`: prdm"
                     Write-Host "3`: nfs"
                 }
                 Write-Host ""
                 [int]$userselection = Read-Host "Please select from this list (1-3)"
                 if ($userselection -eq "") { $userselection = $defaultmode }
                 if ($userselection -eq 1) {  $mountmode = "vrdm"  }
                 if ($userselection -eq 2) {  $mountmode = "prdm"  }
                 if ($userselection -eq 3) {  $mountmode = "nfs"  }
         
                 # map to all ESX host 
                 Clear-Host
                 Write-Host "Map to all ESX Hosts"
                 Write-Host "1`: Do not map to all ESX Hosts(default)"
                 Write-Host "2`: Map to all ESX Hosts"
                 Write-Host ""
                 [int]$userselection = Read-Host "Please select from this list (1-2)"
                 if ($userselection -eq "") { $userselection = 1 }
                 if ($userselection -eq 1) {  $mapdiskstoallesxhosts = "false"  }
                 if ($userselection -eq 2) {  $mapdiskstoallesxhosts = "true"  }
             }
         }
         # mount action
         write-host ""
         Write-Host "Mount action" 
         Write-Host "1`: Agent managed mountpoint(default)"
         Write-Host "2`: Specify mount location"
         Write-Host "3`: Map only"
         Write-Host ""
         $userselection = ""
         [int]$userselection = Read-Host "Please select from this list (1-3)"
         if ($userselection -eq "") { $userselection = "agentmanaged" }
         if ($userselection -eq 1) {  $mountaction = "agentmanaged"  }
         if ($userselection -eq 2) {  $mountaction = "specifymountlocation"  }
         if ($userselection -eq 3) {  $mountaction = "maponly"  }



        if ($mountaction -eq "specifymountlocation")
        {
            if (!($mountlocation))
            {
                $mountlocation = Read-Host "Mount location for the image (optional)"
            }
        }

        Clear-Host
        Write-Host "Guided selection is complete.  The values entered would result in the following command:"
        Write-Host ""
        Write-Host -nonewline "New-AGMLibLVMMount -appid $appid -targethostid $targethostid -imageid $imageid -mountaction $mountaction" 
        if ($uservolumelistfinal)
        {
            Write-Host -nonewline " -volumes `"$uservolumelistfinal`""
        }
        if ($mountapplianceid)
        {
            Write-Host -nonewline " -mountapplianceid $mountapplianceid"
        }
        if ($volumemappings)
        {
            Write-Host -nonewline " -volumemappings `"$volumemappings`""
        }
        if ($mountmode)
        {
            Write-Host -nonewline " -mountmode $mountmode -mapdiskstoallesxhosts $mapdiskstoallesxhosts"
        }
        if ($mountlocation)
        {
            Write-Host -nonewline " -mountlocation `"$mountlocation`""
        }
        if ($prescript)
        {
            Write-Host -nonewline " -prescript `"$prescript`""
        }
        if ($postscript)
        {
            Write-Host -nonewline " -postscript `"$postscript`""
        }
        Write-Host ""
        Write-Host "1`: Run the command now (default)"
        Write-Host "2`: Show the JSON used to run this command, but don't run it"
        Write-Host "3`: Exit without running the command.  If you save the command, remove the imageid to always use the most recent backup."
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
    if (!($mountaction))
    {
        $mountaction = "agentmanaged"
    }    


    # if user asked for volumes
    if ($mountaction -eq "agentmanaged")
    {
        # now see if user wants mount points or drives per volume
        $vollist = $restorableobjects | select-object name | sort-object name
        $selectedobjects = @(
            foreach ($volume in $vollist.name)
            {
                [pscustomobject]@{restorableobject=$volume}
            }   
        )     

        $selectedobjects = @()
        foreach ($volume in $vollist.name)
        {
            $selectedobjects = $selectedobjects + [ordered]@{
                restorableobject = $volume
            }
        } 


    }
    
    if (!($imageid))
    {
        [string]$imageid = Read-Host "ImageID to mount"
    }


    if (!($mountmode))
    {
        $physicalrdm = 2
        $rdmmode = "nfs"
    }
    else 
    {
        if ($mountmode -eq "vrdm")
        {
            $physicalrdm = 0
            $rdmmode = "independentvirtual"
        }
        if ($mountmode -eq "prdm")
        {
            $physicalrdm = 1
            $rdmmode = "physical"
        }
        if ($mountmode -eq "nfs")
        {
            $physicalrdm = 2
            $rdmmode = "nfs"
        }
    }

    if ($mapdiskstoallesxhosts)
    {
        if (($mapdiskstoallesxhosts -ne "true") -and  ($mapdiskstoallesxhosts -ne "false"))
        {
            Get-AGMErrorMessage -messagetoprint "The value of Map to all ESX hosts of $mapdiskstoallesxhosts is not valid.  Must be true or false"
            return
        }
        $restoreoptions = @(
            @{
                name = 'mapdiskstoallesxhosts'
                value = "$mapdiskstoallesxhosts"
            }
        )
    }

    if ($mountaction -eq "specifymountlocation")
    {
        $restoreoptions  = @(
            @{
                name = 'mountpointperimage'
                value = "$mountlocation"
            }
        )
    }

    if ($mountaction -eq "maponly")
    {
        $restoreoptions = @(
            @{
                name = 'maponly'
                value = $true
            }
        )
    }
    

    # handle script
    if ($prescript)
    {
        $script = @( [ordered]@{ phase = "PRE" ; name = $prescript } )
    }
    if ($postscript)
    {
        $script = @( [ordered]@{ phase = "POST" ; name = $postscript } )
    }
    if (($prescript) -and ($postscript))
    {
        $script = @( [ordered]@{ phase = "PRE" ; name = $prescript } ; [ordered]@{ phase = "POST" ; name = $postscript })
    }

    if (!($label))
    {
        $label = ""
    }

    $body = [ordered]@{
        label = $label;
        host = @{id=$targethostid}
        hostclusterid = $mountapplianceid;
    }
    if ($selectedobjects)
    {
        $body = $body + [ordered]@{ selectedobjects = $selectedobjects }
    }
    if ($restoreoptions)
    {
        $body = $body + [ordered]@{ restoreoptions = $restoreoptions }
    }
    if ($restoreobjectmappings)
    {
        $body = $body + [ordered]@{ restoreobjectmappings = $restoreobjectmappings }
    }
    if ($mountmode)
    {
        $body = $body + @{ physicalrdm = $physicalrdm }
        $body = $body + @{ rdmmode = $rdmmode }
    }
    if ($script)
    {
        $body = $body + [ordered]@{ script = $script }
    }


    $json = $body | ConvertTo-Json

    if ($monitor)
    {
        $wait = $true
    }

    if ($jsonprint -eq "yes")
    {
        $compressedjson = $body | ConvertTo-Json -compress
        Write-host "This is the final command:"
        Write-host ""
        Write-host "Post-AGMAPIData  -endpoint /backup/$imageid/mount -body `'$compressedjson`'"
        return
    }

    Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json
    if ($wait)
    {
        Start-Sleep -s 15
        $i=1
        while ($i -lt 9)
        {
            Clear-Host
            write-host "Checking for a running job for appid $appid against targethostname $targethostname"
            $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=False&targethost=$targethostname" -sort queuedate:desc -limit 1 
            if (!($jobgrab.jobname))
            {
                write-host "Job not running yet, will wait 15 seconds and check again.  Check $i of 8"
                Start-Sleep -s 15
                $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=False&targethost=$targethostname" -sort queuedate:desc -limit 1 
                if (!($jobgrab.jobname))
                {
                    $i++
                }
            }
            else
            {   
                $i=9
                $jobgrab| select-object jobname,status,progress,queuedate,startdate,targethost
                
            }
        }
        if (($jobgrab.jobname) -and ($monitor))
        {
            Get-AGMLibFollowJobStatus $jobgrab.jobname
        }
    }
}
