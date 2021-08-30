Function New-AGMLibVMExisting ([string]$appid,[string]$appname,[string]$targethostname,[string]$targethostid,[string]$mountapplianceid,[string]$imageid,[string]$imagename,[string]$label,[string]$mountmode,[string]$volumes,[string]$mapdiskstoallesxhosts,[string]$mountdriveperimage,[string]$mountpointperimage,[switch][alias("g")]$guided,[switch][alias("m")]$monitor,[switch][alias("w")]$wait) 
{
    <#
    .SYNOPSIS
    Mounts an image of a VM to an existing host

    .EXAMPLE
    New-AGMLibVMExisting -g

    Runs a guided menu to mount an image of a VMware VM to a host

    .EXAMPLE
    New-AGMLibVMExisting -targethostid 655167 -imageid 5856288  -volumes "[DS3512_04] SYDWINSQL2/SYDWINSQL2_13.vmdk,[DS3512_04] SYDWINSQL2/SYDWINSQL2_17.vmdk" -mountmode nfs -mapdiskstoallesxhosts false -mountdriveperimage "k:\"

    In this example we mount image ID 5856288 to target host ID 655167.
    We select two volumes to mount.
    We choose NFS mount mode
    We choose to mount the drives starting with the K:\

    .DESCRIPTION
    A function to mount VMware VM images to an existing host

    * Image selection can be done three ways:

    1)  Run this command in guided mode to learn the available images and select one
    2)  Learn the imagename or imageid and specify that as part of the command with -imagename or -imageid
    3)  Learn the Appid and Cluster ID for the appliance that will mount the image and then use -appid and -mountapplianceid 
    This will use the latest snapshot, dedupasync, StreamSnap or OnVault image on that appliance


    * VMware specific options
    -mountmode    use either   nfs, vrdm or prdm
    -mapdiskstoallesxhosts   Either true to do this or false to not do this.  Default is false.   
    
    * Monitoring options:

    -wait     This will wait up to 2 minutes for the job to start, checking every 15 seconds to show you the job name
    -monitor  Same as -wait but will also run Get-AGMLibFollowJobStatus to monitor the job to completion 

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    $sessiontest = Get-AGMVersion
    if (!($sessiontest.summary))
    {
        Get-AGMErrorMessage -messagetoprint "AGM session has expired. Please login again using Connect-AGM"
        return
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

    if ( ($appid) -and (!($appname)) )
    {
        $appgrab = Get-AGMApplication -filtervalue id=$appid
        if(!($appgrab))
        {
            Get-AGMErrorMessage -messagetoprint "Cannot find appid $appid"
            return
        }
        else 
        {
            $appname = ($appgrab).appname
        }
    }


    # if the user gave us nothing to start work, then ask for a VMware VM name
    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $true
        Clear-Host
        Write-host "VM source selection menu"
        Write-host ""
        $vmgrab = Get-AGMApplication -filtervalue "apptype=VMBackup&managed=True" | sort-object appname
        if ($vmgrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "There are no Managed VMware apps to list"
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
                $vmname = $vm.appname
                $appliance = $vm.cluster.name 
                Write-Host -Object "$i`: $vmname ($appliance)"
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




    # if we got a target name lets check it
    if ($targethostname)
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
            $hostid = $hostgrab.id
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
    if ($targethostid)
    {
        $hostgrab = Get-AGMHost -filtervalue id=$targethostid
        if ($hostgrab.id.count -eq -0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $targethostid to a single host ID.  Use Get-AGMLibHostID and try again specifying -targethostid"
            return
        }
        $hostid = $targethostid
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
    

    # learn about the image if the user gave it
    if ($imagename)
    {
        $imagegrab = Get-AGMImage -filtervalue backupname=$imagename
        if ($imagegrab.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imagename using:  Get-AGMImage -filtervalue backupname=$imagename"
            return
        }
        else 
        {
            $imageid = $imagegrab.id
        }
    }

    

    # this if for guided menu
    if ($guided)
    {
        if (!($imageid))
        {
            Clear-Host
            Write-Host "Image selection"
            $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&jobclass=dedupasync"  | select-object -Property backupname,consistencydate,endpit,id,jobclass,cluster | Sort-Object consistencydate,jobclass
            if ($imagelist.id.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Failed to fetch any Images for appid $appid"
                return
            }   
            Clear-Host
            Write-Host "Image list.  Choose the best jobclass and consistency date on the best appliance"
            write-host ""
            $i = 1
            foreach ($image in $imagelist)
            { 
                $image | Add-Member -NotePropertyName select -NotePropertyValue $i
                $image | Add-Member -NotePropertyName appliancename -NotePropertyValue $image.cluster.name
                $i++
            }
            #print the list
            $imagelist | select-object select,consistencydate,jobclass,appliancename,backupname,id | Format-table *
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
            $appname = $imagegrab.appname
            $appid = $imagegrab.application.id   
            $mountapplianceid = $imagegrab.cluster.clusterid
            $mountappliancename = $imagegrab.cluster.name
        }


        if ( (!($targethostname)) -and (!($targethostid)))
        {
            Clear-Host
            $hostgrab = Get-AGMHost -filtervalue "clusterid=$mountapplianceid&sourcecluster=$mountapplianceid&originalhostid=0&hosttype!VMCluster&hosttype!esxhost&hosttype!NetApp 7 Mode&hosttype!NetApp SVM&hosttype!ProxyNASBackupHost&hosttype!Isilon" | sort-object vmtype,hostname
            if ($hostgrab.id.count -eq -0)
            {
                Get-AGMErrorMessage -messagetoprint "Failed to find any hosts on $mountappliancename"
                return
            }
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
            $hostid = $hostgrab.id[($userselection - 1)]
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

        if (!($label))
        {
            Clear-Host
            [string]$label = Read-host "Label"
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
        # see if user wants moint drive or point per image
        Clear-Host
        $mountdriveperimage = ""
        $mountdriveperimage = Read-Host "Mount Drive for the image (Windows only, optional)"
        if ($mountdriveperimage -eq "")
        {
            $mountpointperimage = ""
            $mountpointperimage = Read-Host "Mount Point for the image (optional)"
        }
        # now see if user wants mount points or drives per VMDK
        $imagegrab = Get-AGMimage -id $imageid 
        $imagename = $imagegrab.backupname
        $vollist1 = $imagegrab | select-object restorableobjects
        $vollist = $vollist1.restorableobjects | select-object name | sort-object name
    
        if (!($vollist))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any volumes"
            return
        }
        if ($vollist.count -eq 1) 
        {
            $selectedobjects = @(
                    [pscustomobject]@{restorableobject=$vollist.name}
            )
            $uservolumelistfinal = $vollist.name
        }
        else
        {
            Clear-Host
            Write-Host "Volume list (either enter 0 or a comma separated list e.g.   1,2)"
            Write-Host "0`: All volumes (default)"
            $i = 1
            foreach ($volume in $vollist.name)
            { 
                Write-Host -Object "$i`: $volume"
                $i++
            }
            [string]$userselection = Read-Host "Please select from this list (0 or comma separated list)"
            $uservolumelist = ""
            if (($userselection -eq "0") -or ($userselection -eq ""))
            {
                $selectedobjects = @(
                    foreach ($volume in $vollist.name)
                    {
                        [pscustomobject]@{restorableobject=$volume}
                    }   
                )
                foreach ($volume in $vollist.name)
                {
                    $uservolumelist = $uservolumelist + "," + $volume 
                }
                $uservolumelistfinal = $uservolumelist.substring(1)
            }
            else
            {
                $selectedobjects = @(
                    foreach ($selection in $userselection.Split(","))
                    {
                        [pscustomobject]@{restorableobject=$vollist.name[($selection - 1)]}
                    }   
                )
                foreach ($selection in $userselection.Split(","))
                {
                    $uservolumelist = $uservolumelist + "," + $vollist.name[($selection - 1)] 
                }
                $uservolumelistfinal = $uservolumelist.substring(1)
            }
        }

        Clear-Host
        Write-Host "Guided selection is complete.  The values entered would result in the following command:"
        Write-Host ""
        Write-Host -nonewline "New-AGMLibVMExisting -targethostid $hostid -appid $appid -imageid $imageid -mountapplianceid $mountapplianceid -volumes `"$uservolumelistfinal`""
        if ($mountmode)
        {
            Write-Host -nonewline " -mountmode $mountmode -mapdiskstoallesxhosts $mapdiskstoallesxhosts"
        }
        if ($mountdriveperimage)
        {
            Write-Host -nonewline " -mountdriveperimage `"$mountdriveperimage`""
        }
        if ($mountpointperimage)
        {
            Write-Host -nonewline " -mountpointperimage `"$mountpointperimage`""
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


    if (($appid) -and ($mountapplianceid) -and (!($imageid)))
    {
        # if we are not running guided mode but we have an appid without imageid, then lets get the latest image on the mountappliance ID
        $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot&jobclass=StreamSnap&jobclass=dedupasync&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:asc" -limit 1
        if ($imagegrab.count -eq 1)
        {   
            $imageid = $imagegrab.id
            $imagename = $imagegrab.backupname
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot, dedupasync, StreamSnap or OnVault Image for appid $appid on appliance with clusterID $mountapplianceid"
            return
        }
    }
        
    # if user asked for volumes
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

    if (!($imagename))
    {
        $imagename = (Get-AGMImage -id $imageid).backupname
    }

    if (!($mountmode))
    {
        $physicalrdm = 0
        $rdmmode = "independentvirtual"
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

    if ($mountpointperimage)
    {
        if ($restoreoptions)
        {
            $imagemountpoint = @{
                name = 'mountpointperimage'
                value = "$mountpointperimage"
            }
            $restoreoptions = $restoreoptions + $imagemountpoint
        }
        else 
        {
            $restoreoptions = @(
            @{
                name = 'mountpointperimage'
                value = "$mountpointperimage"
            }
        )
        }
    }

    if ($mountdriveperimage)
    {
        if ($restoreoptions)
        {
            $imagemountpoint = @{
                name = 'mountdriveperimage'
                value = "$mountdriveperimage"
            }
            $restoreoptions = $restoreoptions + $imagemountpoint
        }
        else 
        {
            $restoreoptions = @(
            @{
                name = 'mountdriveperimage'
                value = "$mountdriveperimage"
            }
        )
        }
    }


    if (!($label))
    {
        $label = ""
    }

    $body = [ordered]@{
        label = $label;
        image = $imagename;
        host = @{id=$hostid}
        migratevm = "false";
    }
    if ($restoreoptions)
    {
        $body = $body + [ordered]@{ restoreoptions = $restoreoptions }
    }
    if ($selectedobjects)
    {
        $body = $body + [ordered]@{ selectedobjects = $selectedobjects }
    }
    if ($mountmode)
    {
        $body = $body + @{ physicalrdm = $physicalrdm }
        $body = $body + @{ rdmmode = $rdmmode }
    }
    if ($restoreobjectmappings)
    {
        $body = $body + @{ restoreobjectmappings = $restoreobjectmappings }
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
