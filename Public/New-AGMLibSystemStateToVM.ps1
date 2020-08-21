Function New-AGMLibSystemStateToVM ([int]$appid,[string]$appname,[int]$imageid,[string]$vmname,[string]$imagename,[string]$datastore,[string]$poweronvm,[int]$esxhostid,[int]$vcenterid,[string]$dhcpnetworks,[string]$fixedipnetworks,[switch][alias("g")]$guided) 
{
    <#
    .SYNOPSIS
    Mounts a system state image as a new VM

    .EXAMPLE
    New-AGMLibSystemStateToVM -g

    Runs a guided menu to create a new VMware VM from a system state image. 

    .DESCRIPTION
    A function to create a new VMware VM from a System State Image

    poweroffvm - by default is not set and VM is left powered on
    selectedobjects - currently not cated for 
    cpu - autolearned from the image so they should only be issued if you want to vary them from the per image default
    memory - autolearned from the image so they should only be issued if you want to vary them from the per image default
    ostype - autolearned from the image so they should only be issued if you want to vary them from the per image default

    dhcpnetworks - each network is semi-colon separated with two comma separated variables, the network name and the NIC Type
    format example, single network:  "Network1,E10000"   
    format example, two networks:  "Network1,E10000;Network2,VMXNet3"

    fixedipnetworks  - each network is semi-colon separated with six comma separated variables, the network name, the NIC Type, IP Address, Subnet, Gateway, DNS
    format example, single network:   "Network1,VMXNet3,10.0.0.100,10.0.0.1,255.255.255.0,8.8.8.8"
    format example, two networks:   "Network1,VMXNet3,10.0.0.100,10.0.0.1,255.255.255.0,8.8.8.8;Network2,VMXNet3,10.1.0.100,10.1.0.1,255.255.255.0,8.8.8.8"
    
    Note image defaults can be shown with:   Get-AGMImageSystemStateOptions -imageid $imageid -target VMware
    

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    else 
    {
        $sessiontest = (Get-AGMSession).session_id
        if ($sessiontest -ne $AGMSESSIONID)
        {
            Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
            return
        }
    }


    # if the user gave us nothing to start work, then ask for a VMware VM name
    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $true
        Clear-Host
        $vmgrab = Get-AGMApplication -filtervalue "apptype=SystemState&managed=True" | sort-object appname
        if ($vmgrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "There are no Managed System State apps to list"
            return
        }
        if ($vmgrab.count -eq 1)
        {
            $appname =  $vmgrab.appname
            $appid = $vmgrab.id
            write-host "Found one SystemState app $appname"
            write-host ""
        }
        else 
        {
            write-host "VM Selection menu"
            Write-host ""
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
                $appname =  $vmgrab.appname[($vmselection - 1)]
                $appid = $vmgrab.id[($vmselection - 1)]
            }
        }
    }

    if ( ($appname) -and (!($appid)) )
    {
        $appgrab = Get-AGMApplication -filtervalue "appname=$appname&apptype=SystemState"
        if ($appgrab.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appname to a unique valid SystemState app.  Use Get-AGMLibApplicationID and try again specifying -appid."
            return
        }
        else {
            $appid = $appgrab.id
        }
    }

    
    # learn name of new VM
    if (!($vmname))
    {
        [string]$vmname= Read-Host "Name of New VM you want to create"
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
            write-host "Fetching Image list from AGM for Appid $appid"
            $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault"  | select-object -Property backupname,consistencydate,id,targetuds,jobclass,cluster | Sort-Object consistencydate
            if ($imagelist.count -eq 0)
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
                $targetappliance = $image.cluster.name
                Write-Host -Object "$i`:  $($image.consistencydate) $($image.jobclass) ($targetappliance)"
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


        Clear-Host
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
    
        Write-Host "Power off after recovery?"
        Write-Host "1`: Do not power off after recovery(default)"
        Write-Host "2`: Power off after recovery"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $poweronvm = $TRUE  }
        if ($userselection -eq 2) {  $poweronvm = $FALSE  }

        $systemstateoptions = Get-AGMImageSystemStateOptions -imageid $imageid -target VMware
        $cpudefault = $ostype = ($systemstateoptions| where-object {$_.name -eq "CPU"}).defaultvalue
        $memorydefault = $ostype = ($systemstateoptions| where-object {$_.name -eq "Memory"}).defaultvalue
        $ostype = ($systemstateoptions| where-object {$_.name -eq "OSType"}).defaultvalue
        $nicinfo = ($systemstateoptions | where-object {$_.name -eq "NICInfo"}).structure 
        $niclist = ($nicinfo | where-object {$_.name -eq "NICType"}).choices.name
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
        [int]$networkcount = Read-Host "Number of network interfaces (default is 1)"
        if (!($networkcount)) { $networkcount = 1 }
        $dhcpnetworks = ""
        $fixedipnetworks = ""
        foreach ($net in 1..$networkcount)
        {
            clear-host
            Write-host "Network $net settings"
            Write-Host ""
            Write-Host "DHCP Selection"
            Write-Host "1`: Use DHCP(default)"
            Write-Host "2`: Set IP Addresses"
            Write-Host ""
            if ($userselection -eq "") { $userselection = 1 }
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "1")
            {
                $networkname = Read-Host "VMware Network Name"  
                Write-Host ""
                Write-Host "NIC Type"
                Write-Host "1`: Use VMXNet3(default)"
                Write-Host "2`: Use E10000"
                Write-Host ""
                [int]$usernicselection = Read-Host "Please select from this list (1-2)"
                if ($usernicselection -eq "2") { $dhcpnetworks = $dhcpnetworks + ";" +  $networkname + "," + "E10000" } else { $dhcpnetworks = $dhcpnetworks + ";" +  $networkname + "," + "VMXNet3" }
            }
            if ($userselection -eq "2")
            {
                $networkname = Read-Host "VMware Network Name"  
                Write-Host ""
                Write-Host "NIC Type"
                Write-Host "1`: Use VMXNet3(default)"
                Write-Host "2`: Use E10000"
                Write-Host ""
                [int]$usernicselection = Read-Host "Please select from this list (1-2)"
                write-host ""
                $ipaddress = Read-Host "IP Address" 
                $subnet = Read-Host "Subnet" 
                $gateway = Read-Host "Gateway" 
                $dns = Read-Host "DNS" 
                if ($usernicselection -eq "2") { $fixedipnetworks = $fixedipnetworks + ";" +  $networkname + "," + "E10000" + "," + $ipaddress + "," + $subnet + "," + $gateway + "," + $dns } else { $fixedipnetworks = $fixedipnetworks + ";" +  $networkname + "," + "VMXNet3" + "," + $ipaddress + "," + $subnet + "," + $gateway + "," + $dns}
            }
        }
        if ($dhcpnetworks -ne "") { $dhcpnetworks = $dhcpnetworks.substring(1) }
        if ($fixedipnetworks -ne "") { $fixedipnetworks = $fixedipnetworks.substring(1) }


        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline  "New-AGMLibSystemStateToVM -imageid $imageid -vmname $vmname -datastore `"$datastore`" -vcenterid $vcenterid -esxhostid $esxhostid"
        if ($poweroffvm) { Write-Host -nonewline " -poweroffvm" }
        if ($dhcpnetworks -ne "") { Write-Host " -dhcpnetworks `"$dhcpnetworks`"" }
        if ($fixedipnetworks -ne "") { Write-Host " -fixedipnetworks `"$fixedipnetworks`"" }
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

    if ( (!($datastore)) -or (!($esxhostid)) -or (!($vcenterid)) )
    {
        Get-AGMErrorMessage -messagetoprint "Please supply -datastore -esxhostid and -vcenterid or use -g to build the command"
        return
    }

    $body = [ordered]@{}
    

    $body += [ordered]@{
        datastore = $datastore;
        hypervisor = @{id=$esxhostid}
        mgmtserver = @{id=$vcenterid}
        hostname = $vmname;
    }
    if ($poweroffvm) { $body += [ordered]@{ poweronvm = "false" } } else { $body += [ordered]@{ poweronvm = "true" } }
    $systemstateoptions = @()
    $systemstateoptions += @( 
        [ordered]@{ name = 'CPU'; value = $cpu }
        [ordered]@{ name = 'Memory'; value = $memory } 
        [ordered]@{ name = 'OSType'; value = $ostype } 
        [ordered]@{ name = 'CloudType'; value = "VMware" }  
    )

    if ($dhcpnetworks)
    {
        $nicinfo = @()
        foreach ($nic in $dhcpnetworks.split(";"))
        {
            $nicinfo += @(
                [ordered]@{ name = 'DHCP'; value = "true" } 
                [ordered]@{ name = 'NICNetwork'; value = $nic.split(",")[0] } 
                [ordered]@{ name = 'NICType'; value = $nic.split(",")[1] } 
            )
            $systemstateoptions += @( 
                [ordered]@{ name = 'NICInfo'; structurevalue = $nicinfo }
            )
        }
    }
    if ($fixedipnetworks)
    {
        $nicinfo = @()
        foreach ($nic in $fixedipnetworks.split(";"))
        {
            $nicinfo += @(
                [ordered]@{ name = 'DHCP'; value = "false" } 
                [ordered]@{ name = 'NICNetwork'; value = $nic.split(",")[0] } 
                [ordered]@{ name = 'NICType'; value = $nic.split(",")[1] } 
                [ordered]@{ name = 'NICIP'; value = $nic.split(",")[2] }
                [ordered]@{ name = 'NICSubnet'; value = $nic.split(",")[3] }
                [ordered]@{ name = 'NICGateway'; value = $nic.split(",")[4] }
                [ordered]@{ name = 'NICDNS'; value = $nic.split(",")[5] }
            )
            $systemstateoptions += @( 
                [ordered]@{ name = 'NICInfo'; structurevalue = $nicinfo }
            )
        }
    }
    $body += [ordered]@{ systemstateoptions = $systemstateoptions }
    $body += [ordered]@{ migratevm = "false" }

    $json = $body | ConvertTo-Json -depth 4

    if ($monitor)
    {
        $wait = "y"
    }

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