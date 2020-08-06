Function New-AGMLibVM ([int]$appid,[string]$appname,[int]$imageid,[string]$vmname,[string]$imagename,[string]$datastore,[string]$mountmode,[string]$poweronvm,[string]$volumes,[int]$esxhostid,[int]$vcenterid,[string]$mapdiskstoallesxhosts,[switch][alias("g")]$guided,[switch][alias("m")]$monitor,[switch][alias("w")]$wait) 
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
    Valid values for mountmode are:   nfs, vrdm or prdm with vrdm being the default if nothing is selected.

    .DESCRIPTION
    A function to create new VMs using a mount job

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }


    # if the user gave us nothing to start work, then ask for a VMware VM name
    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $true
        Clear-Host
        write-host "VM Selection menu"
        Write-host ""
        $vmgrab = Get-AGMApplication -filtervalue "apptype=VMBackup&managed=True" | sort-object appname
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
    else 
    {
        if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
        {
            $appname = read-host "AppName of the source VM"
        }
    }

    if ( ($appname) -and (!($appid)) )
    {
        $appgrab = Get-AGMApplication -filtervalue "appname=$appname&apptype=VMBackup"
        if ($appgrab.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appname to a unique valid VMBackup app.  Use Get-AGMLibApplicationID and try again specifying -appid."
            return
        }
        else {
            $appid = $appgrab.id
        }
    }

    
    # learn name of new VM
    if (!($vmname))
    {
        [string]$vmname= Read-Host "Name of New VM you want to create using an image of $appname"
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
            Clear-Host
            Write-Host "Image selection"
            Write-Host "1`: Use the latest snapshot(default)"
            Write-Host "2`: Select an image"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if (($userselection -eq "") -or ($userselection -eq 1))
            {
                $imagecheck = Get-AGMLibLatestImage $appid
                if (!($imagecheck.backupname))
                {
                    Get-AGMErrorMessage -messagetoprint "Failed to find snapshot for AppID using:  Get-AGMLibLatestImage $appid"
                    return
                }   
                else {
                    $imagegrab = Get-AGMImage -id $imagecheck.id
                    $imagename = $imagegrab.backupname                
                    $imageid = $imagegrab.id
                    $consistencydate = $imagegrab.consistencydate
                    $restorableobjects = $imagegrab.restorableobjects
                }
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
                    $consistencydate = $imagegrab.consistencydate
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
                    $consistencydate = $imagegrab.consistencydate 
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
        Write-Host "1`: vrdm (default)"
        Write-Host "2`: prdm"
        Write-Host "3`: nfs"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-3)"
        if ($userselection -eq "") { $userselection = 1 }
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
        Write-Host "New-AGMLibVM -imageid $imageid -vmname $vmname -datastore `"$datastore`" -vcenterid $vcenterid -esxhostid $esxhostid -mountmode $mountmode -mapdiskstoallesxhosts $mapdiskstoallesxhosts -poweronvm $poweronvm -volumes `'$uservolumelistfinal`'"
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
        [int]$imageid = Read-Host "ImageID to mount"
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

    if (!($selectedobjects))
    {
        $body = [ordered]@{
            "@type" = "mountRest";
            label = $label
            restoreoptions = @(
                @{
                    name = 'mapdiskstoallesxhosts'
                    value = "$mapdiskstoallesxhosts"
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
            migratevm = "false";
        }
    }
    else 
    {
        $body = [ordered]@{
            "@type" = "mountRest";
            label = $label
            restoreoptions = @(
                @{
                    name = 'mapdiskstoallesxhosts'
                    value = "$mapdiskstoallesxhosts"
                }
            )
            datastore = $datastore;
            hypervisor = @{id=$esxhostid}
            mgmtserver = @{id=$vcenterid}
            vmname = $vmname;
            hostname = $vmname;
            poweronvm = "$poweronvm";
            physicalrdm = $physicalrdm;
            rdmmode = $rdmmode
            selectedobjects = @(
                $selectedobjects
            )
            migratevm = "false";
        }
    }




    $json = $body | ConvertTo-Json

    if ($monitor)
    {
        $wait = "y"
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
        $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=false&targethost=$targethostname" -sort queuedate:desc -limit 1 
        if (!($jobgrab.jobname))
        {
            Start-Sleep -s 15
            $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=false&targethost=$targethostname" -sort queuedate:desc -limit 1 
            if (!($jobgrab.jobname))
            {
                return
            }
        }
        else
        {   
            $jobgrab| select-object jobname,status,queuedate,startdate,targethost
            
        }
        if (($jobgrab.jobname) -and ($monitor))
        {
            Get-AGMFollowJobStatus $jobgrab.jobname
        }
    }
}