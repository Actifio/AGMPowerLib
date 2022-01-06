Function New-AGMLibGCPVM ([string]$appid,[string]$mountapplianceid,
[string]$appname,
[string]$imageid,[string]$imagename,
[string]$vmname,
[switch]$poweroffvm,
[string]$rehydrationmode,
[string]$selectedobjects,
[int]$cpu,
[int]$memory,
[string]$ostype,
[string]$gcpkeyfile,
[string]$volumeType,
[string]$tags,
[string]$projectid,
[string]$sharedvpcprojectid,
[string]$regioncode,
[string]$zone,
[string]$network,
[string]$network1,
[string]$network2,
[string]$network3,
[string]$network4,
[string]$network5,
[string]$network6,
[string]$network7,
[string]$network8,
[string]$network9,
[string]$network10,
[string]$network11,
[string]$network12,
[string]$network13,
[string]$network14,
[string]$network15,
[int]$bootdisksize,
[switch]$migratevm,
[switch][alias("g")]$guided) 
{
    <#
    .SYNOPSIS
    Mounts an image as a new GCP VM

    .EXAMPLE
    New-AGMLibGCPVM -g

    Runs a guided menu to create a new GCP VM.  

    .EXAMPLE
    New-AGMLibGCPVM -appid 20933978 -mountapplianceid 1415033486 -vmname "avtest20" -gcpkeyfile "/Users/anthony/Downloads/actifio-sales-310-a95fd43f4d8b.json" -volumetype "SSD persistent disk" -projectid "project1" -regioncode "us-east4" -zone "us-east4-b" -network1 "default;sa-1;"

    This mounts the latest image for the specified appid using the specified cluster ID.
    The subnet ID is "default" and the network ID is "sa-1" 

    .EXAMPLE
    New-AGMLibGCPVM -imageid 1234 -vmname "avtest20" -gcpkeyfile "/Users/anthony/Downloads/actifio-sales-310-a95fd43f4d8b.json" -volumetype "SSD persistent disk" -projectid "project1" -regioncode "us-east4" -zone "us-east4-b" -network1 "default;sa-1;"

    This mounts the specified image.
    The subnet ID is "default" and the network ID is "sa-1"

    .DESCRIPTION
    A function to create new GCP VMs using a mount job

    Image selection can be done three ways:

    1)  Run this command in guided mode to learn the available images and select one
    2)  Learn the image ID and specify that as part of the command with -imageid
    3)  Learn the Appid and Cluster ID for the appliance that will mount the image and then use -appid and -mountapplianceid 
    This will use the latest snapshot, dedupasync, StreamSnap or OnVault image on that appliance

    poweroffvm - by default is not set and VM is left powered on
    rehydrationmode - OnVault only can be: StorageOptimized,Balanced, PerformanceOptimized or MaximumPerformance
    selectedobjects - currently not cated for 
    cpu - autolearned from the image so they should only be issued if you want to vary them from the per image default
    memory - autolearned from the image so they should only be issued if you want to vary them from the per image default
    ostype - autolearned from the image so they should only be issued if you want to vary them from the per image default
    gcpkeyfile - just give full path and file name, don't paste in file contents
    volumeType - Get list by running:   Get-AGMImageSystemStateOptions -imageid $imageid -target GCP
    tags - comma separate if you have multiple
    regioncode - Get list by running:   Get-AGMImageSystemStateOptions -imageid $imageid -target GCP
    zone - Get list by running:   Get-AGMImageSystemStateOptions -imageid $imageid -target GCP
    privateipaddresses - comma separate if you have multiple
    bootdisksize - autolearned from the image so they should only be issued if you want to vary them from the per image default
    migratevm - by default is not set

    Note image defaults can be shown with:   Get-AGMImageSystemStateOptions -imageid $imageid -target GCP
    
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

    # if the user gave us nothing to start work, then ask for a VMware VM name
    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $TRUE
        write-host "Running guided mode"

        $appliancegrab = Get-AGMAppliance | select-object name,clusterid | sort-object name
        if ($appliancegrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any appliances to list"
            return
        }
        if ($appliancegrab.count -eq 1)
        {
            $mountapplianceid = $appliancegrab.clusterid
            $mountappliancename =  $appliancegrab.name
        }
        else
        {
            Clear-Host
            write-host "Appliance selection menu - which Appliance will run this mount"
            Write-host ""
            $i = 1
            foreach ($appliance in $appliancegrab)
            { 
                Write-Host -Object "$i`: $($appliance.name)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $appliancegrab.name.count
                [int]$appselection = Read-Host "Please select an Appliance to mount from (1-$listmax)"
                if ($appselection -lt 1 -or $appselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $mountapplianceid =  $appliancegrab.clusterid[($appselection - 1)]
            $mountappliancename =  $appliancegrab.name[($appselection - 1)]
        }
        Write-host ""
        write-host "Select application status for VMWare/SystemState apps with images on $mountappliancename"
        Write-host ""
        Write-Host "1`: Managed local apps(default)"
        Write-Host "2`: Unmanaged local apps"
        Write-Host "3`: Imported apps (from other Appliances)"
        Write-Host ""
        [int]$userselectionapps = Read-Host "Please select from this list (1-3)"
        if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { $vmgrab = Get-AGMApplication -filtervalue "managed=true&apptype=SystemState&apptype=VMBackup&clusterid=$mountapplianceid" | sort-object appname }
        if ($userselectionapps -eq 2) { $vmgrab = Get-AGMApplication -filtervalue "managed=false&apptype=SystemState&apptype=VMBackup&sourcecluster=$mountapplianceid" | sort-object appname  }
        if ($userselectionapps -eq 3) { $vmgrab = Get-AGMApplication -filtervalue "apptype=SystemState&apptype=VMBackup&sourcecluster!$mountapplianceid&clusterid=$mountapplianceid" | sort-object appname }
        if ($vmgrab.count -eq 0)
        {
            if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { Get-AGMErrorMessage -messagetoprint "There are no managed System State or VMware apps to list." }
            if ($userselectionapps -eq 2)  { Get-AGMErrorMessage -messagetoprint "There are no unmanaged System State or VMware apps to list." }
            if ($userselectionapps -eq 3)  { Get-AGMErrorMessage -messagetoprint "There are no imported System State or VMware apps to list.  You may need to run Import-AGMLibOnVault first" }
            return
        }
        if ($vmgrab.count -eq 1)
        {
            $appname =  $vmgrab.appname
            $appid = $vmgrab.id
            write-host "Found one app $appname"
            write-host ""
        }
        else
        {
            Clear-Host
            write-host "VM Selection menu"
            Write-host ""
            $i = 1
            foreach ($vm in $vmgrab)
            { 
                Write-Host -Object "$i`: $($vm.appname) ($($vm.apptype)) on $($vm.cluster.name)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $vmgrab.appname.count
                [int]$vmselection = Read-Host "Please select an application (1-$listmax)"
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
    else 
    {
        if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
        {
            $appname = read-host "AppName of the source VM"
        }
    }

    if ( ($appname) -and (!($appid)) )
    {
        $appgrab = Get-AGMApplication -filtervalue "appname=$appname&apptype=VMBackup&apptype=SystemState"
        if ($appgrab.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appname to a unique valid VMBackup or System State app.  Use Get-AGMLibApplicationID and try again specifying -appid."
            return
        }
        else {
            $appid = $appgrab.id
        }
    }

    
    # learn name of new VM
    if (!($vmname))
    {
        While ($true)  { if ($vmname -eq "") { [string]$vmname= Read-Host "Name of New VM you want to create using an image of $appname" } else { break } }
    }

    # learn about the image
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

    # this if for guided menu
    if ($guided)
    {
        if (!($imagename))
        {
            write-host "Fetching Image list from AGM"
            $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&jobclass=dedupasync&clusterid=$mountapplianceid"  | select-object -Property backupname,consistencydate,id,targetuds,jobclass,cluster,diskpool | Sort-Object consistencydate
            if ($imagelist.id.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Failed to fetch any Images for appid $appid"
                return
            }

            Clear-Host
            Write-Host "Image list.  Choose based on the best consistency date, location and jobclass."
            $i = 1
            foreach
            ($image in $imagelist)
            { 
                if ($image.jobclass -eq "OnVault")
                {
                    $target = $image.diskpool.name
                    Write-Host -Object "$i`:  $($image.consistencydate) $($image.jobclass) (Diskpool: $target)"
                }
                else
                {
                    $target = $image.cluster.name
                    Write-Host -Object "$i`:  $($image.consistencydate) $($image.jobclass) (Appliance: $target)"
                }
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
            $jobclass = $imagelist[($imageselection - 1)].jobclass
        }
    }

    if (($appid) -and ($mountapplianceid) -and (!($imageid)))
    {
        # if we are not running guided mode but we have an appid without imageid, then lets get the latest image on the mountappliance ID
        $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot&jobclass=dedupasync&jobclass=StreamSnap&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:asc" -limit 1
        if ($imagegrab.count -eq 1)
        {   
            $imageid = $imagegrab.id
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot, dedupasync, StreamSnap or OnVault Image for appid $appid on appliance with clusterID $mountapplianceid"
            return
        }
    }


    $systemstateoptions = Get-AGMImageSystemStateOptions -imageid $imageid -target GCP
    $cpudefault = $ostype = ($systemstateoptions| where-object {$_.name -eq "CPU"}).defaultvalue
    $memorydefault = $ostype = ($systemstateoptions| where-object {$_.name -eq "Memory"}).defaultvalue
    $bootdiskdefault = $ostype = ($systemstateoptions| where-object {$_.name -eq "BootDiskSize"}).defaultvalue
    $ostype = ($systemstateoptions| where-object {$_.name -eq "OSType"}).defaultvalue
    $volumetypelist = ($systemstateoptions| where-object {$_.name -eq "volumeType"}).choices.name
    $regioncodelist = ($systemstateoptions| where-object {$_.name -eq "RegionCode"}).choices
    # so many settings to explore
    if ($guided)
    {
        Clear-Host
        Write-Host ""
        Write-Host "Migrate VM?"
        Write-Host "1`: Do not migrate VM(default)"
        Write-Host "2`: Migrate the VM to cloud storage"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $migratevm = $FALSE  }
        if ($userselection -eq 2) {  $migratevm = $TRUE  }
        Write-Host "Power off after recovery?"
        Write-Host "1`: Do not power off after recovery(default)"
        Write-Host "2`: Power off after recovery"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $poweronvm = $TRUE  }
        if ($userselection -eq 2) {  $poweronvm = $FALSE  }
        Write-Host ""
        [int]$cpu = read-host "CPU (vCPU) (default $cpudefault)"
        [int]$memory = read-host "Memory (GB) (default $memorydefault)"

        # this shouldn't be needed
        if (!($ostype))
        {
            Write-Host ""
            Write-Host "OS TYPE?"
            Write-Host "1`: Windows(default)"
            Write-Host "2`: Linux"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $userselection = 1 }
            if ($userselection -eq 1) {  $ostype = "Windows"  }
            if ($userselection -eq 2) {  $ostype = "Linux"  }
        }
        else 
        {
            write-host "`nOS type: $ostype"    
        }
        Write-Host ""
        While ($true) 
        {
            [string]$gcpkeyfile = read-host "Name of GCP key file (with full path to file)"
            # if (Test-Path $gcpkeyfile)     
            if ([IO.File]::Exists($gcpkeyfile))
            {
                break
            } 
            else
            {
                Write-Host -Object "Could not locate $gcpkeyfile.  Ensure full path to file name is supplied"
            }
        }

        Write-Host ""
        Write-Host "Disk Type"
        $i = 1
        $listmax = $volumetypelist.Length
        foreach ($disktype in $volumetypelist)
        { 
            Write-Host -Object "$i`: $disktype"
            $i++
        }
        [int]$userselection = Read-Host "Please select from this list (1-$listmax)"
        if ($userselection -eq "") { $userselection = 1 }
        $volumetype = $volumetypelist[($userselection - 1)]
        Write-Host ""
        [string]$tags = Read-Host "Tags (comma separated)"
        While ($true)  { if ($projectid -eq "") { [string]$projectid = Read-Host "Project ID (VPC)" } else { break } }
        [string]$sharedvpcprojectid = Read-Host "Shared VPC projectid (optional)"

        Write-Host "Region Code"
        $i = 1
        $listmax = $regioncodelist.Length
        foreach ($region in $regioncodelist.name)
        { 
            Write-Host -Object "$i`: $region"
            $i++
        }
        While ($true) 
        {
            [int]$userselection = Read-Host "Please select from this list (1-$listmax)"
            if ($userselection -lt 1 -or $userselection -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
            } 
            else
            {
                break
            }
        }
        $regioncode = $regioncodelist.name[($userselection - 1)]
    
        Write-Host "Zone"
        $zonelist = ($regioncodelist | where-object {$_.name -eq $regioncode}).subselect.choices.name
        $i = 1
        $listmax = $zonelist.Length
        foreach ($choice in $zonelist)
        { 
            Write-Host -Object "$i`: $choice"
            $i++
        }
        While ($true) 
        {
            [int]$userselection = Read-Host "Please select from this list (1-$listmax)"
            if ($userselection -lt 1 -or $userselection -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
            } 
            else
            {
                break
            }
        }
        $zone = $zonelist[($userselection - 1)]

        #networks
        [int]$networkcount = Read-Host "Number of networks (default is 1)"
        if (!($networkcount)) { $networkcount = 1 }
        foreach ($net in 1..$networkcount)
        {
            write-host ""
            Write-host "Network $net settings"
            Write-Host ""
            $networkinformation = ""
            $networkid = ""
            While ($true)  { if ($networkid -eq "") { [string]$networkid = Read-Host "Network ID (mandatory)" } else { break } }
            $networkinformation = $networkid + ";"
            $subnetid = ""
            While ($true)  { if ($subnetid -eq "") { [string]$subnetid = Read-Host "Subnet ID (mandatory)" } else { break } }
            $networkinformation = $networkinformation + $subnetid + ";"
            $privateipinfo = ""
            [int]$privateipcount = Read-Host "Number of Private IPs (default is 0)"
            if (!($privateipcount)) { $privateipcount = 0 }
            if ($privateipcount -gt 0) 
            {
                foreach ($privip in 1..$privateipcount)
                {
                    [string]$privateip = ""
                    While ($true)  { if ($privateip -eq "") { [string]$privateip = Read-Host "Private IP Address"} else { break } }
                    $privateipinfo = $privateipinfo + "," + $privateip
                }
            }
            if ($privateipinfo -ne "") { $privateipinfo = $privateipinfo.substring(1) }
            $networkinformation = $networkinformation + $privateipinfo 
            
    
            New-Variable -Name "network$net" -Value $networkinformation -force
        }

        [int]$bootdisksize = read-host "Boot Disk Size(default $bootdiskdefault)"

        if ($jobclass -eq "OnVault")
        {
            Write-Host ""
            Write-Host "OnVault Performance & Consumption Options"
            Write-Host "1`: Storage Optimized (performance depends on network, least storage consumption)"
            Write-Host "2`: Balanced (more performance, more storage consumption) - Default"
            Write-Host "3`: Performance Optimized (higher performance, highest storage consumption)"
            Write-Host "4`: Maximum Performance (delay before mount, highest performance, highest storage consumption)"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-4)"
            if ($userselection -eq "") { $userselection = 2 }
            if ($userselection -eq 1) {  $rehydrationmode = "StorageOptimized"  }
            if ($userselection -eq 2) {  $rehydrationmode = "Balanced"  }
            if ($userselection -eq 3) {  $rehydrationmode = "PerformanceOptimized"  }
            if ($userselection -eq 4) {  $rehydrationmode = "MaximumPerformance"  }
        }
    }

    #some defaults
    if (!($cpu)) { $cpu = $cpudefault }
    if (!($memory)) { $memory = $memorydefault }
    if (!($bootdisksize)) { $bootdisksize = $bootdiskdefault }  

    if ($guided)
    {
        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline "New-AGMLibGCPVM -imageid $imageid -appid $appid -mountapplianceid $mountapplianceid -vmname `"$vmname`" -cpu $cpu -memory $memory -ostype `"$OSType`" -gcpkeyfile `"$gcpkeyfile`" -volumetype `"$volumetype`" -projectid `"$projectid`""
        if ($tags) { Write-Host -nonewline " -tags `"$tags`"" }
        if ($sharedvpcprojectid) { Write-Host -nonewline " -sharedvpcprojectid `"$sharedvpcprojectid`"" } 
        Write-Host -nonewline " -regioncode `"$regioncode`" -zone `"$zone`""
        if ($network) { Write-Host -nonewline " -network1 `"$network`""}
        if ($network1) { Write-Host -nonewline " -network1 `"$network1`""}
        if ($network2) { Write-Host -nonewline " -network2 `"$network2`""}
        if ($network3) { Write-Host -nonewline " -network3 `"$network3`""}
        if ($network4) { Write-Host -nonewline " -network4 `"$network4`""}
        if ($network5) { Write-Host -nonewline " -network5 `"$network5`""}
        if ($network6) { Write-Host -nonewline " -network6 `"$network6`""}
        if ($network7) { Write-Host -nonewline " -network7 `"$network7`""}
        if ($network8) { Write-Host -nonewline " -network8 `"$network8`""}
        if ($network9) { Write-Host -nonewline " -network9 `"$network9`""}
        if ($network10) { Write-Host -nonewline " -network10 `"$network10`""}
        if ($network11) { Write-Host -nonewline " -network11 `"$network11`""}
        if ($network12) { Write-Host -nonewline " -network12 `"$network12`""}
        if ($network13) { Write-Host -nonewline " -network13 `"$network13`""}
        if ($network14) { Write-Host -nonewline " -network14 `"$network14`""}
        if ($network15) { Write-Host -nonewline " -network15 `"$network15`""}  
        Write-Host -nonewline " -bootdisksize $bootdisksize"
        if ($poweroffvm) { Write-Host -nonewline " -poweroffvm" }
        if ($migratevm) { Write-Host -nonewline " -migratevm" }
        if ($rehydrationmode) { Write-Host -nonewline " -rehydrationmode `"$rehydrationmode`"" }
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

    if (Test-Path $gcpkeyfile)
    {
        $gcpkey = [IO.File]::ReadAllText($gcpkeyfile)
    }
    $body = [ordered]@{}
    $body += @{ hostname = $vmname }
    if ($poweroffvm) { $body += @{ poweronvm = "false" } } else { $body += @{ poweronvm = "true" } }
    $body += @{ rehydrationmode = $rehydrationmode }
    # selected objects needed
    # [string]$selectedobjects,
    $systemstateoptions = @()
    $systemstateoptions += @( 
        [ordered]@{ name = 'CPU'; value = $cpu }
        [ordered]@{ name = 'Memory'; value = $memory } 
        [ordered]@{ name = 'OSType'; value = $ostype } 
        [ordered]@{ name = 'CloudType'; value = "GCP" }  
        [ordered]@{ name = 'GCPkeys'; value = $gcpkey } 
        [ordered]@{ name = 'volumeType'; value = $volumetype } 
    )

    if ($tags)
    {
        foreach ($tag in $tags.split(","))
        {
            $systemstateoptions += @(
            [ordered]@{ name = 'tags'; value = $tag } 
            )
        }
    }
    if ($projectid)
    {
        $systemstateoptions += @( 
            [ordered]@{ name = 'alternateProjectId'; value = $projectid } 
        )
    }
    
    if ($sharedvpcprojectid)
    {
        $systemstateoptions += @(   
            [ordered]@{ name = 'hostprojectid'; value = $sharedvpcprojectid } 
        )
    }    
    $systemstateoptions += @(   
        [ordered]@{ name = 'RegionCode'; value = $regioncode } 
        [ordered]@{ name = 'Zone'; value = $zone } 
    )
    # add all the networks!
    foreach ($netinfo in $network,$network1,$network2,$network3,$network4,$network5,$network6,$network7,$network8,$network9,$network10,$network11,$network12,$network13,$network14,$network15)
    {
        if ($netinfo)
        {
            $nicinfo = @()
            $nicinfo = @( @{ name = 'NetworkId' ; value = $netinfo.split(";")[0] } )
            $nicinfo += @( @{ name = 'SubnetId' ; value = $netinfo.split(";")[1] } )
            $networksplit2 = $netinfo.split(";")[2]
            foreach ($value in $networksplit2.split(","))
            {   
                if ($value -ne "" ) { $nicinfo += @( @{ name = 'privateIpAddresses' ; value = $value } ) }
            }

            $systemstateoptions += @( 
                [ordered]@{ name = 'NICInfo'; structurevalue = $nicinfo }
            )
        }
    }
    $systemstateoptions += @( 
        [ordered]@{ name = 'BootDiskSize'; value = $bootdisksize }
    )
    $body += [ordered]@{ systemstateoptions = $systemstateoptions }
    if ($migratevm) { $body += @{ migratevm = "true" } } else { $body += @{ migratevm = "false" } }

    $json = $body | ConvertTo-Json -depth 4


    if ($jsonprint -eq "yes")
    {
        $compressedjson = $body | ConvertTo-Json -compress -depth 4
        Write-host "This is the final command:"
        Write-host ""
        Write-host "Post-AGMAPIData  -endpoint /backup/$imageid/mount -body `'$compressedjson`'"
        return
    }

    Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json
}