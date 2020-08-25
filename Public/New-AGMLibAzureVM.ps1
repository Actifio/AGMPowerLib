Function New-AGMLibAzureVM ([int]$appid,[string]$appname,[int]$imageid,[string]$imagename,
[string]$vmname,
[switch]$migratevm,
[switch]$poweroffvm,
[string]$rehydrationmode,
[string]$selectedobjects,
[int]$cpu,
[int]$memory,
[string]$ostype,
[string]$resourcegroupname,
[string]$storageaccount,
[string]$volumeType,
[string]$regioncode,
[string]$networkid,
[string]$clientid,
[string]$domain,
[string]$secretkey,
[string]$subscriptionId,
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
[switch][alias("g")]$guided) 
{
    <#
    .SYNOPSIS
    Mounts an image as a new Azure VM

    .EXAMPLE
    New-AGMLibAzureVM -g

    Runs a guided menu to create a new Azure VM.  


    .DESCRIPTION
    A function to create new Azure VMs using a mount job

    poweroffvm - by default is not set and VM is left powered on
    rehydrationmode - OnVault only can be: StorageOptimized,Balanced, PerformanceOptimized or MaximumPerformance
    selectedobjects - currently not cated for 
    cpu - autolearned from the image so they should only be issued if you want to vary them from the per image default
    memory - autolearned from the image so they should only be issued if you want to vary them from the per image default
    bootdisksize - autolearned from the image so they should only be issued if you want to vary them from the per image default
    ostype - autolearned from the image so they should only be issued if you want to vary them from the per image default
    volumeType - Get list by running:   Get-AGMImageSystemStateOptions -imageid $imageid -target Azure
    regioncode - Get list by running:   Get-AGMImageSystemStateOptions -imageid $imageid -target Azure
    privateipaddresses - comma separate if you have multiple
    bootdisksize - autolearned from the image so they should only be issued if you want to vary them from the per image default
    migratevm - by default is not set
       networks - each network should have three semi-colon separated sections:
    subnet id ; SecurityGroupIds comma separated ; private IPs comma separate
    e.g.:     1234;5678,9012;10.1.1.1,10.1.1.1

    Note image defaults can be shown with:   Get-AGMImageSystemStateOptions -imageid $imageid -target Azure
    
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
        

        write-host "Fetching VM and SystemState list from AGM for $mountappliancename"
        $vmgrab = Get-AGMApplication -filtervalue "apptype=SystemState&apptype=VMBackup&managed=True&clusterid=$mountapplianceid" | sort-object appname
        if ($vmgrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "There are no Managed System State or VMBackup apps to list"
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
            $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&clusterid=$mountapplianceid"  | select-object -Property backupname,consistencydate,id,targetuds,jobclass,cluster | Sort-Object consistencydate
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
    }
    $systemstateoptions = Get-AGMImageSystemStateOptions -imageid $imageid -target Azure
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
        # migrate VM
        Write-Host "Migrate VM?"
        Write-Host "1`: Do not migrate VM(default)"
        Write-Host "2`: Migrate the VM to cloud storage"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $migratevm = $FALSE  }
        if ($userselection -eq 2) {  $migratevm = $TRUE  }
        # power off
        Write-Host "Power off after recovery?"
        Write-Host "1`: Do not power off after recovery(default)"
        Write-Host "2`: Power off after recovery"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $poweronvm = $TRUE  }
        if ($userselection -eq 2) {  $poweronvm = $FALSE  }
        Write-Host ""
        # cpu and memory
        [int]$cpu = read-host "CPU (vCPU) (default $cpudefault)"
        [int]$memory = read-host "Memory (GB) (default $memorydefault)"
        # ostype shouldn't be needed
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
        #resource group name and storage account
        While ($true)  { if ($resourcegroupname -eq "") { [string]$resourcegroupname = Read-Host "Resource Group Name"} else { break } }
        While ($true)  { if ($storageaccount -eq "") { [string]$storageaccount = Read-Host "Storage Account"} else { break } }
        #volume type
        Write-Host "Volume Type"
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
        # region code
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
        # network ID
        While ($true)  { if ($networkid -eq "") { [string]$networkid = Read-Host "Network ID"} else { break } }
        # four secret things
        While ($true)  { if ($encclientid.length -eq 0) {  $encclientid = Read-Host -AsSecureString "Client ID" } else { break } }
        $clientid = ConvertFrom-SecureString -SecureString $encclientid -AsPlainText

        While ($true)  { if ($encdomain.length -eq 0) {  $encdomain = Read-Host -AsSecureString "Domain" } else { break } }
        $domain = ConvertFrom-SecureString -SecureString $encdomain -AsPlainText

        While ($true)  { if ($encsecretkey.length -eq 0) {  $encsecretkey = Read-Host -AsSecureString "Secret Key" } else { break } }
        $secretkey = ConvertFrom-SecureString -SecureString $encsecretkey -AsPlainText

        While ($true)  { if ($encsubscriptionId.length -eq 0) {  $encsubscriptionId = Read-Host -AsSecureString "Subscription ID" } else { break } }
        $subscriptionId = ConvertFrom-SecureString -SecureString $encsubscriptionId -AsPlainText

        #networks
        [int]$networkcount = Read-Host "Number of networks (default is 1)"
        if (!($networkcount)) { $networkcount = 1 }
        foreach ($net in 1..$networkcount)
        {
            write-host ""
            Write-host "Network $net settings"
            Write-Host ""
            [string]$subnetid = ""
            While ($true)  { if ($subnetid -eq "") { [string]$subnetid = Read-Host "Subnet ID"} else { break } }
            $networkinformation = $subnetid + ";"

            $secgroupinfo = ""
            [int]$securitygroupcount = Read-Host "Number of Security Groups (default is 1)"
            if (!($securitygroupcount)) { $securitygroupcount = 1 }
            foreach ($secgroup in 1..$securitygroupcount)
            {
                [string]$securitygroupid = ""
                While ($true)  { if ($securitygroupid -eq "") { [string]$securitygroupid = Read-Host "Security Group ID"} else { break } }
                $secgroupinfo = $secgroupinfo + "," + $securitygroupid
            }
            if ($secgroupinfo -ne "") { $secgroupinfo = $secgroupinfo.substring(1) }
            $networkinformation = $networkinformation + $secgroupinfo + ";"

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
        # GUI doesn't ask, so don't ask here either
        # [int]$bootdisksize = read-host "Boot Disk Size(default $bootdiskdefault)"

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
        Write-Host -nonewline "New-AGMLibAzureVM -imageid $imageid -vmname `"$vmname`""
        if ($poweroffvm) { Write-Host -nonewline " -poweroffvm" }
        if ($rehydrationmode) { Write-Host -nonewline " -rehydrationmode `"$rehydrationmode`""}
        Write-Host -nonewline " -cpu $cpu -memory $memory -ostype `"$OSType`" -resourcegroupname `"$resourcegroupname`" -storageaccount `"$storageaccount`" -volumetype `"$volumetype`" -regioncode `"$regioncode`"  -networkid `"$networkid`" -clientid ******* -domain ******* -secretkey ******* -subscriptionid *******"
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
        if ($migratevm) { Write-Host -nonewline " -migratevm" }
        Write-Host ""
        Write-Host "1`: Run the command now (default) - NOTE the access ID and secret key ID are not shown here"
        Write-Host "2`: Show the JSON used to run this command, but don't run it - NOTE the access ID and secret key ID will be shown here"
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

    $body = [ordered]@{}
    $body += @{ hostname = $vmname }
    if ($poweroffvm) { $body += @{ poweronvm = "false" } } else { $body += @{ poweronvm = "true" } }
    if ($rehydrationmode) { $body += @{ rehydrationmode = $rehydrationmode } }
    # selected objects needed
    # [string]$selectedobjects,
    $systemstateoptions = @()
    $systemstateoptions += @( 
        [ordered]@{ name = 'CPU'; value = $cpu }
        [ordered]@{ name = 'Memory'; value = $memory } 
        [ordered]@{ name = 'OSType'; value = $ostype } 
        [ordered]@{ name = 'CloudType'; value = "Azure" }  
        [ordered]@{ name = 'resourcegroup'; value = $resourcegroup } 
        [ordered]@{ name = 'storageaccount'; value = $storageaccount } 
        [ordered]@{ name = 'volumeType'; value = $volumetype } 
        [ordered]@{ name = 'RegionCode'; value = $regioncode } 
        [ordered]@{ name = 'NetworkId'; value = $networkid }
        [ordered]@{ name = 'ClientId'; value = $clientid }
        [ordered]@{ name = 'Domain'; value = $domain }
        [ordered]@{ name = 'SecretKey'; value = $secretkey }
        [ordered]@{ name = 'subscriptionId'; value = $subscriptionid }
    )
    # add all the networks!
    foreach ($netinfo in $network,$network1,$network2,$network3,$network4,$network5,$network6,$network7,$network8,$network9,$network10,$network11,$network12,$network13,$network14,$network15)
    {
        if ($netinfo)
        {
            $nicinfo = @()
            $nicinfo = @( @{ name = 'SubnetId' ; value = $netinfo.split(";")[0] } )
            $networksplit1 = $netinfo.split(";")[1]
            foreach ($value in $networksplit1.split(","))
            {   
                $nicinfo += @( @{ name = 'SecurityGroupId' ; value = $value } )
            }
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
    # bootdisk size
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