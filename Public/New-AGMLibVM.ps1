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


Function New-AGMLibVM ([string]$appid,[string]$appname,[string]$imageid,[string]$vmname,[string]$imagename,[string]$datastore,[string]$mountmode,[string]$poweronvm,[string]$volumes,[string]$esxhostid,[string]$vcenterid,[string]$mapdiskstoallesxhosts,[string]$label,[switch][alias("g")]$guided,[switch][alias("m")]$monitor,[switch][alias("w")]$wait,[string]$onvault,[string]$perfoption,[switch]$restoremacaddr,[switch]$jsonprint) 
{
    <#
    .SYNOPSIS
    Mounts an image as a new VM

    .EXAMPLE
    New-AGMLibVM -g

    Runs a guided menu to create a new VM.  The only thing you need is the name of the source VM.  

    .EXAMPLE
    New-AGMLibVM -imageid 53773979 -vmname avtestvm9 -datastore "ORA-RAC-iSCSI" -vcenterid 5552150 -esxhostid 5552164 -mountmode nfs 

    In this example we mount image ID 53773979 as a new VM called avtestvm9 to the specified vCenter/ESX host.  
    Valid values for mountmode are:   nfs, vrdm or prdm with nfs being the default if nothing is selected.

    .DESCRIPTION
    A function to create new VMs using a mount job

    * Mount options:
    -appid         If you specify this, then don't specify appname, imagename or imageid.   We will find the most recent imaage and mount that as a new VM.
    -perfoption    You can specify either:  StorageOptimized, Balanced, PerformanceOptimized or MaximumPerformance
                   Note if you run this option when mounting a snapshot image, the mount will fail
    -restoremacaddr This will assign the MAC Address from the source VM to the target VM.   Do this in DR situations where you need to preserve the MAC Address

    * Monitoring options:

    -wait     This will wait up to 2 minutes for the job to start, checking every 15 seconds to show you the job name
    -monitor  Same as -wait but will also run Get-AGMLibFollowJobStatus to monitor the job to completion 
    -appid  xxxx  Will mount the latest snapshot for appid xxxx rather than requiring the user to supply an image name/id
    -onvault true  Will use the latest OnVault image rather than latest snapshot image when used with -appid 

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

    # if the user gave us nothing to start work, then offer a guided menu to select a VM
    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $true
        Clear-Host
        write-host "VM Selection menu"
        Write-host ""
        $vmgrab = Get-AGMApplication -filtervalue "apptype=VMBackup" | sort-object appname
        if ($vmgrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "There are no VMware apps to list"
            return
        }
        if ($vmgrab.count -eq 1)
        {
            $appname =  $vmgrab.appname
            $appid = $vmgrab.id
            write-host "Found one VMware app $appname"
            write-host ""
        }
        else 
        {
            $i = 1
            foreach ($vm in $vmgrab)
            { 
                $vmlistname = $vm.appname
                $appliance = $vm.cluster.name 
                Write-Host -Object "$i`: $vmlistname ($appliance)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $vmgrab.appname.count
                [int]$vmselection = Read-Host "Please select a protected VM (1-$listmax)"
                if ($vmselection -lt 1 -or $vmselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $appname =  $vmgrab.appname[($vmselection - 1)]
            $appid = $vmgrab.id[($vmselection - 1)]
        }
    }


    
    # learn name of new VM
    if (!($vmname))
    {
        [string]$vmname= Read-Host "Name of New VM you want to create using an image of $appname"
    }

    # if we got just an an imagename, we can work with this.  First check that it exists and then learn the image ID of that imagename
    if ($imagename) 
    {
        $imagegrab = Get-AGMImage -filtervalue backupname=$imagename
        if ($imagegrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imagename using:  Get-AGMImage -filtervalue backupname=$imagename"
            return
        }
        else 
        {
            $imageid = $imagegrab.id
        }
    }


    # if we got appname but no appid, we need to learn the appid
    if (($appname) -and (!($appid)))
    {
        $vmgrab = Get-AGMApplication -filtervalue "apptype=VMBackup&appname=$appname" | sort-object appname
        if ($vmgrab.appname.count -eq 1)
        {
            $appid = $vmgrab.id
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find a unique appid for appname $appname"
            return
        }
    }


    # if we got an appid and we are not in guided mode, then we need to find the latest image
    if (($appid) -and (!($guided)))
    {
        if ($onvault -eq "true")
        {
            $imagecheck = Get-AGMLibLatestImage -jobclass OnVault -appid $appid
        }
        else 
        {
            $imagecheck = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=OnVault&jobclass=StreamSnap" -sort "jobclasscode:asc,consistencydate:desc" -limit 1
        }
        
        if (!($imagecheck.backupname))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to any images for $appname ($appid)"
            return
        }   
        else {
            $imagegrab = Get-AGMImage -id $imagecheck.id
            $imagename = $imagegrab.backupname                
            $imageid = $imagegrab.id
            $restorableobjects = $imagegrab.restorableobjects
        }
    }
    


    # this if for guided menu.  We previously used guided menu to find an appid/appname.   Now we find an image
    if ($guided)
    {
        if (!($imagename))
        {
            Clear-Host
            Write-Host "Image selection"
            Write-Host "1`: Use the latest snapshot(default)"
            Write-Host "2`: Use the latest OnVault"
            Write-Host "3`: Select an image"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-3)"
            if (($userselection -eq "") -or ($userselection -eq 1))
            {
                $imagecheck = Get-AGMLibLatestImage -appid $appid
                if (!($imagecheck.backupname))
                {
                    Get-AGMErrorMessage -messagetoprint "Failed to find snapshot for AppID using:  Get-AGMLibLatestImage -appid $appid"
                    return
                }   
                else {
                    $imagegrab = Get-AGMImage -id $imagecheck.id
                    $imagename = $imagegrab.backupname                
                    $imageid = $imagegrab.id
                    $restorableobjects = $imagegrab.restorableobjects
                }
            }
            elseif  ($userselection -eq 2)
            {
                $imagecheck = Get-AGMLibLatestImage -jobclass OnVault -appid $appid
                if (!($imagecheck.backupname))
                {
                    Get-AGMErrorMessage -messagetoprint "Failed to find OnVault for AppID using:  Get-AGMLibLatestImage -jobclass Onvault -appid $appid"
                    return
                }   
                else {
                    $imagegrab = Get-AGMImage -id $imagecheck.id
                    $imagename = $imagegrab.backupname                
                    $imageid = $imagegrab.id
                    $restorableobjects = $imagegrab.restorableobjects
                }
                write-host ""
                Write-Host "Performance and Consumption Options"
                Write-Host "1`: Storage Optimized (performance depends on network, least storage consumption)"
                Write-Host "2`: Balanced (more performance, more storage consumption)(default)"
                Write-Host "3`: Performance Optimized (higher performance, highest storage consumption)"
                Write-Host "4`: Maximum Performance (delay before mount, highest performance, highest storage consumption)"
                Write-Host ""
                [int]$perfselection = Read-Host "Please select from this list (1-4)"
                if ($perfselection -eq "1") { $perfoption = "StorageOptimized" }
                if (($perfselection -eq "2") -or ($perfselection -eq "")) { $perfoption = "Balanced" }
                if ($perfselection -eq "3") { $perfoption = "PerformanceOptimized" }
                if ($perfselection -eq "4") { $perfoption = "MaximumPerformance" }



            }
            else
            {
                $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot"  | select-object -Property backupname,consistencydate,endpit,id | Sort-Object consistencydate
                if ($imagelist.backupname.count -eq 0)
                {
                    Get-AGMErrorMessage -messagetoprint "Failed to fetch any snapshot Images for appid $appid"
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
                    Write-Host "Snapshot list.  Choose the best consistency date."
                    $i = 1
                    foreach
                    ($image in $imagelist.consistencydate)
                        { Write-Host -Object "$i`:  $image"
                        $i++
                    }
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
                }
            }
        }


        Clear-Host
        if (!($label))
        {
            Clear-Host
            $label = Read-Host "Label"
        }
        #using the image we learn which appliance it is on.  We need this so we can list only the vCenters known to that appliance
        $clusterid = (Get-AGMImage -id $imageid).clusterid
        if (!($clusterid))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find details about $imageid"
            return
        }
        
        # we now learn what vcenters are on that appliance and build a list, if there is more than 1
        $vclist = Get-AGMHost -filtervalue "clusterid=$clusterid&isvcenterhost=true&hosttype=vcenter" | select-object -Property name, srcid, id | Sort-Object name

        if ($vclist.name.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any vCenters"
            return
        }
        elseif ($vclist.name.count -eq 1) 
        {
            $vcenterid = ($vclist).id
            $srcid =  ($vclist).srcid
        }
        else
        {
            Clear-Host
            Write-Host "vCenter list"
            $i = 1
            foreach
            ($item in $vclist.name)
                { Write-Host -Object "$i`: $item"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $vclist.Length
                [int]$userselection = Read-Host "Please select from this list (1-$listmax)"
                if ($userselection -lt 1 -or $userselection -gt $vclist.Length)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($vclist.Length)]"
                } 
                else
                {
                    break
                }
            }
            $srcid =  $vclist[($userselection - 1)].srcid
            $vcenterid = $vclist[($userselection - 1)].id
        }
        # we now learn what ESX hosts are known to the selected vCenter
        $esxlist = Get-AGMHost -filtervalue "vcenterhostid=$srcid&isesxhost=true&originalhostid=0"  | select-object -Property id, name | Sort-Object name
        if ($esxlist.name.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any ESX Servers"
            return
        }
        elseif ($esxlist.name.count -eq 1)
        {
            $esxhostid =  ($esxlist).id
        } 
        else
        {
            Clear-Host
            Write-Host "ESX Server list"
            $i = 1
            foreach
            ($server in $esxlist.name)
                { Write-Host -Object "$i`: $server"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $esxlist.Length
                [int]$esxserverselection = Read-Host "Please select an ESX Server (1-$listmax)"
                if ($esxserverselection -lt 1 -or $esxserverselection -gt $esxlist.Length)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($esxlist.Length)]"
                } 
                else
                {
                    break
                }
            }
            $esxhostid =  $esxlist[($esxserverselection - 1)].id
        }

        # we now learn what datastores are known to the selected ESX host
        $dslist = (Get-AGMHost -id $esxhostid).sources.datastorelist | select-object name,freespace | sort-object name | Get-Unique -asstring

        if ($dslist.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any DataStores"
            return
        }
        elseif ($dslist.count -eq 1) 
        {
            $datastore =  ($dslist).name
        }
        else
        {
            Clear-Host
            Write-Host "Datastore list"
            $i = 1
            foreach ($item in $dslist)
            { 
                $diskname = $item.name
                $freespace = [math]::Round($item.freespace / 1073741824,0)
                Write-Host -Object "$i`: $diskname ($freespace GiB Free)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $dslist.Length
                [int]$userselection = Read-Host "Please select from this list (1-$listmax)"
                if ($userselection -lt 1 -or $userselection -gt $dslist.Length)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($dslist.Length)]"
                } 
                else
                {
                    break
                }
            }
            $datastore =  $dslist[($userselection - 1)].name
        }
        #   VRDM FOR NEW MOUNTS IS ALWAYS THE DEFAULT!   Don't change this unless AGM changes...
        Clear-Host
        Write-Host "Mount mode"
        Write-Host "1`: nfs (default)"
        Write-Host "2`: vrdm"
        Write-Host "3`: prdm"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-3)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $mountmode = "nfs"  }
        if ($userselection -eq 2) {  $mountmode = "vrdm"  }
        if ($userselection -eq 3) {  $mountmode = "prdm"  }

        if ($mountmode -ne "nfs")
        {
            # map to all ESX host 
            Clear-HostZZZZZZ
            Write-Host "Map to all ESX Hosts"
            Write-Host "1`: Do not map to all ESX Hosts(default)"
            Write-Host "2`: Map to all ESX Hosts"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $userselection = 1 }
            if ($userselection -eq 1) {  $mapdiskstoallesxhosts = "false"  }
            if ($userselection -eq 2) {  $mapdiskstoallesxhosts = "true"  }
        }
        else
        {
            $mapdiskstoallesxhosts = "false" 
        }

          # preserve mac addr
          Clear-Host
          Write-Host "Use same Mac Address as source VM"
          Write-Host "1`: no (default)"
          Write-Host "2`: yes"
          Write-Host ""
          [int]$macselection = Read-Host "Please select from this list (1-2)"
          if ($macselection -eq 2) {  $restoremacaddr = $true  }


        # power on new VM
        Clear-Host
        Write-Host "Power on mode"
        Write-Host "1`: Power on VM(default)"
        Write-Host "2`: Do not Power on VM"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $poweronvm = "true"  }
        if ($userselection -eq 2) {  $poweronvm = "false"  }

        #now the volumes 
        Clear-Host
        if ($restorableobjects.name.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any volumes"
            return
        }
        if ($restorableobjects.name.count -eq 1) 
        {
            $selectedobjects = @(
                    [pscustomobject]@{restorableobject=$restorableobjects.name}
            )
            $uservolumelistfinal = $restorableobjects.name
        }
        else
        {
            Clear-Host
            $uservolumelist = ""
            Write-Host "Volume list (either enter 0 or a comma separated list e.g.   1,2)"
            Write-Host "0`: All volumes (default)"
            $i = 1
            foreach
            ($volume in $restorableobjects.name)
                { Write-Host -Object "$i`: $volume"
                $i++
            }
            [string]$userselection = Read-Host "Please select from this list (0 or comma separated list)"
            if (($userselection -eq "0") -or ($userselection -eq ""))
            {
                $selectedobjects = @(
                    foreach ($volume in $restorableobjects.name)
                    {
                        [pscustomobject]@{restorableobject=$volume}
                    }   
                )
                foreach ($volume in $restorableobjects.name)
                {
                    $uservolumelist = $uservolumelist + "," + $volume
                }
                $uservolumelistfinal = $uservolumelist.substring(1)
            }
            else
            {
                $selectedobjects = @(
                    foreach ($volume in $userselection.Split(","))
                    {
                        [pscustomobject]@{restorableobject=$restorableobjects[($volume - 1)].name}
                    }   
                )
                foreach ($volume in $userselection.Split(","))
                {
                    $uservolumelist = $uservolumelist + "," + $restorableobjects[($volume - 1)].name 
                }
                $uservolumelistfinal = $uservolumelist.substring(1)
            }
         }


        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline "New-AGMLibVM -imageid $imageid -vmname $vmname -datastore `"$datastore`" -vcenterid $vcenterid -esxhostid $esxhostid -mountmode $mountmode -mapdiskstoallesxhosts $mapdiskstoallesxhosts -poweronvm $poweronvm -volumes `'$uservolumelistfinal`'"
        if ($label) { Write-Host -nonewline " -label $label" }
        if ($perfoption) { Write-Host -nonewline " -perfoption $perfoption" }
        if ($restoremacaddr) { Write-Host -nonewline " -restoremacaddr" }
        Write-Host ""
        Write-Host "1`: Run the command now (default)"
        Write-Host "2`: Show the JSON used to run this command, but don't run it"
        Write-Host "3`: Exit without running the command"
        $userchoice = Read-Host "Please select from this list (1-3)"
        if ($userchoice -eq 2)
        {
            $jsonprint = $true
        }
        if ($userchoice -eq 3)
        {
            return
        }
    }

    # if user asks for volumes
    if ($volumes)
    {
        $selectedobjects = @(
            foreach ($volume in $volumes.Split(","))
            {
                [pscustomobject]@{restorableobject=$volume}
            }   
        )
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

    if (!($poweronvm))
    {
        $poweronvm = "true"
    }
    if (($poweronvm -ne "true") -and  ($poweronvm -ne "false"))
    {
        Get-AGMErrorMessage -messagetoprint "Power on VM value of $poweronvm is not valid.  Must be true or false"
        return
    }

    if (!($mapdiskstoallesxhosts))
    {
        $mapdiskstoallesxhosts = "false"
    }
    if (($mapdiskstoallesxhosts -ne "true") -and  ($mapdiskstoallesxhosts -ne "false"))
    {
        Get-AGMErrorMessage -messagetoprint "The value of Map to all ESX hosts of $mapdiskstoallesxhosts is not valid.  Must be true or false"
        return
    }

    if ( (!($datastore)) -or (!($esxhostid)) -or (!($vcenterid)) )
    {
        Get-AGMErrorMessage -messagetoprint "Please supply -datastore -esxhostid and -vcenterid or use -g to build the command"
        return
    }
    if (!($restoremacaddr))
    { $macaddressrestore = "false" } 
    else
    { $macaddressrestore = "true" }

    if (!($selectedobjects))
    {
        $body = [ordered]@{
            "@type" = "mountRest";
            label = $label
            restoreoptions = @(
                [ordered] @{
                    name = 'mapdiskstoallesxhosts'
                    value = "$mapdiskstoallesxhosts"
                }
                [ordered] @{
                    name = 'restoremacaddr'
                    value = $macaddressrestore
                }
            )
            datastore = $datastore;
            hypervisor = @{id=$esxhostid}
            mgmtserver = @{id=$vcenterid}
            vmname = $vmname;
            hostname = $vmname;
            poweronvm = "$poweronvm";
            physicalrdm = $physicalrdm;
            rdmmode = $rdmmode;
        }
        if ($perfoption) { $body = $body +@{ rehydrationmode = $perfoption } }
    }
    else 
    {
        $body = [ordered]@{
            "@type" = "mountRest";
            label = $label
            restoreoptions = @(
                [ordered]@{
                    name = 'mapdiskstoallesxhosts'
                    value = "$mapdiskstoallesxhosts"
                }
                [ordered]@{
                    name = 'restoremacaddr'
                    value = $macaddressrestore
                }
            )
            datastore = $datastore;
            hypervisor = @{id=$esxhostid}
            mgmtserver = @{id=$vcenterid}
            vmname = $vmname;
            hostname = $vmname;
            poweronvm = "$poweronvm";
            physicalrdm = $physicalrdm;
            rdmmode = $rdmmode;
            selectedobjects = @(
                $selectedobjects
            )
        }
        if ($perfoption) { $body = $body +@{ rehydrationmode = $perfoption } }
        
    }




    $json = $body | ConvertTo-Json -depth 10 

    if ($monitor)
    {
        $wait = $true
    }

    if ($jsonprint -eq $true)
    {
        $compressedjson = $body | ConvertTo-Json -compress -depth 10
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
            write-host "Checking for a running job for appid $appid against targethostname $vmname"
            $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=False&targethost=$vmname" -sort queuedate:desc -limit 1 
            if (!($jobgrab.jobname))
            {
                write-host "Job not running yet, will wait 15 seconds and check again.  Check $i of 8"
                Start-Sleep -s 15
                $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=False&targethost=$vmname" -sort queuedate:desc -limit 1 
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