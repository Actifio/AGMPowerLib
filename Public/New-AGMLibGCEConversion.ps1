Function New-AGMLibGCEConversion([string]$appid,[string]$appname,[string]$imageid,[string]$imagename,[string]$srcid,[string]$projectname,[string]$sharedvpcprojectid,[string]$nodegroup,[string]$region,[string]$zone,[string]$instancename,[string]$machinetype,[string]$serviceaccount,[string]$networktags,[string]$labels,[string]$nic0network,[string]$nic0subnet,[string]$nic0externalip,[string]$nic0internalip,[string]$nic1network,[string]$nic1subnet,[string]$nic1externalip,[string]$nic1internalip,[switch]$poweroffvm,[switch]$migratevm,[string]$preferedsource,[string]$disktype) 
{
    <#
    .SYNOPSIS
    Mounts a VMware VM or System State image as a new GCP Instance (VM)

    .EXAMPLE
    New-AGMLibGCEConversion -imageid 56410933 -srcid 1234 -region australia-southeast1 -zone australia-southeast1-c -projectname myproject -instancename avtest21 -machinetype e2-micro -networktags "http-server,https-server" -labels "dog:cat,sheep:cow" -nic0network "https://www.googleapis.com/compute/v1/projects/projectname/global/networks/default" -nic0subnet "https://www.googleapis.com/compute/v1/projects/projectname/regions/australia-southeast1/subnetworks/default" -nic0externalip auto -nic0internalip "10.152.0.200" -poweroffvm 

    This mounts the specified imageid 56410933

    .DESCRIPTION
    To learn which Applications are suitable use this command (note the ApplianceName is where the images were created):
    Get-AGMApplication -filtervalue "apptype=SystemState&apptype=VMBackup" | select id,appname,@{N='appliancename'; E={$_.cluster.name}} | sort-object appname

    To learn which Cloud Credential srcids are available use this command:
    Get-AGMLibCredentialSrcID

    To learn the image ID or image name, you could use this command (change jobclass to snapshot or StreamSnap if needed):
    Get-AGMImage -filtervalue "apptype=SystemState&apptype=VMBackup&jobclass=OnVault" | select appname,id,name,consistencydate,@{N='diskpoolname'; E={$_.diskpool.name}} | sort-object appname,consistencydate | format-table
    
    There are many parameters that need to be supplied:

    -appid           The application ID of the source VMWare VM or System State you want to mount.  If you use this you don't need to specify an image ID or imagename.   It will use the latest image of that application.
    -appname         The application name of the source VMWare VM or System State you want to mount.  This needs to be unique.  If you use this you don't need to specify an image ID or imagename.   It will use the latest image of that application.
    -imageid         You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image).  To avoid using this, you can specify -appid or -appname instead
    -imagename       You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image).  To avoid using this, you can specify -appid or -appname instead
    -srcid           Learn this with Get-AGMLibCredentialSrcID.  You need to use the correct srcid that matches the appliance that is going to run the mount.
    -serviceaccount  The service account.
    -projectname     This is the unique Google Project name where the new instance will be created.
    -sharedvpcprojectid  If the instance is being created in a service project, what is the ID the project that is sharing the VPC (optional)
    -nodegroup       If creating an instance into a sole tenant node group, this is the name of the node group (optional)
    -region          This is the GCP Region such as:   australia-southeast1
    -zone            This is the GCP Zone such as: australia-southeast1-c
    -instancename    This is the name of the new instance that will be created.   It needs to be unique in that project
    -machinetype     This is the GCP instance machine type such as:  e2-micro
    -networktags     Comma separate as many tags as you have, for instance:   -networktags "http-server,https-server"   
    -labels          Labels are key value pairs.   Separate key and value with colons and each label with commas.   For example:   -labels "pet:cat,food:fish"
    -nic0network     The network name in URL format for nic0
    -nic0subnet      The subnet name in URL format for nic0
    -nic0externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic0 is 'none'
    -nic0internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic0 will be auto assigned.   
    -poweroffvm      By default the new GCE Instance will be left powered on after creation.   If you want it to be created but then powered off, then specify this flag.
    -migratevm       By default the new GCE Instance will be dependent on the Actifio Appliance.  To migrate all data onto GCE PD, then specify this flag.
    -preferedsource  Optional,  used if we want to force selection of images from a particular storage pool, either snapshot, streamsnap or onvault  (use lower case)

    Optionally you can request a second NIC using nic1:
    -nic1network     The network name in URL format for nic1
    -nic1subnet      The subnet name in URL format for nic1
    -nic1externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic1 is 'none'
    -nic1internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic1 will be auto assigned.   
 
    Optionally you can specify that all disks be a different type:
    -disktype        Has to be one  of pd-balanced, pd-extreme, pd-ssd, pd-standard   All disks in the instance will use this disk type
    
    What is not supported right now:
    1)  Specifying more than one internal IP per subnet.
    2)  Specifying different disk types per disk

    If you get timeouts, then increase the timeout value with -timeout xx when running connect-agm
    
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


    # GUIDED MODE kicks in if we dont have an image or app preference
    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $TRUE
        write-host "Running guided mode"
        write-host ""
        $credentialgrab = Get-AGMLibCredentialSrcID
        if ($credentialgrab.credentialid)
        {
            $credarray = @()
            $i = 1
            foreach ($credential in $credentialgrab)
            {
                $credarray += [pscustomobject]@{
                    id = $i
                    appliancename = $credential.appliancename
                    applianceid = $credential.applianceid
                    credentialname = $credential.credentialname
                    credentialid = $credential.credentialid
                    srcid = $credential.srcid
                }
                $i++
            }
        }
        
        if ($credarray.credentialid.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "There are no Credentials.  Please add a credential"
            return
        }
        if ($credarray.srcid.count -eq 1)
        {
            $srcid =  $credarray.srcid
            $credentialid = $credarray.credentialid
        }
        else
        {
            Clear-Host
            write-host "Welcome to the Guided Menu for GCE Conversion. "
            write-host "You will be offered selections to build a command to run a conversion job that will create a new GCE Instance, either from a VMware VM or System State Backup"
            write-host ""
            write-host "Credential Selection menu"
            write-host "The Credential is used to authenticate GCE commands.  Ensure you select the credential on the correct appliance since this will determine which appliance runs the recovery job"
            Write-host ""
            $credarray | Format-Table
            While ($true)
            {
                Write-host ""
                $listmax = $credarray.credentialname.count
                [int]$credselection = Read-Host "Please select a credential (1-$listmax)"
                if ($credselection -lt 1 -or $credselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                }
                else
                {
                    break
                }
            }
            $srcid = $credarray.srcid[($credselection - 1)]
            $mountapplianceid = $credarray.applianceid[($credselection - 1)]
            $mountappliancename = $credarray.appliancename[($credselection - 1)]
            $credentialid =$credarray.credentialid[($credselection - 1)]
        }

        Write-host ""
        write-host "Select application status for VMWare/SystemState apps with images on $mountappliancename"
        Write-host ""
        Write-Host "1`: Managed local apps (default)"
        Write-Host "2`: Unmanaged local apps"
        Write-Host "3`: Imported apps (from other Appliances).  If you cannot see imported apps, you may need to first run:  Import-AGMLibOnVault"
        Write-Host ""
        [int]$userselectionapps = Read-Host "Please select from this list (1-3)"
        if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { $vmgrab = Get-AGMApplication -filtervalue "managed=true&apptype=SystemState&apptype=VMBackup&clusterid=$mountapplianceid" | sort-object appname }
        if ($userselectionapps -eq 2) { $vmgrab = Get-AGMApplication -filtervalue "managed=false&apptype=SystemState&apptype=VMBackup&sourcecluster=$mountapplianceid" | sort-object appname  }
        if ($userselectionapps -eq 3) { $vmgrab = Get-AGMApplication -filtervalue "apptype=SystemState&apptype=VMBackup&sourcecluster!$mountapplianceid&clusterid=$mountapplianceid" | sort-object appname }
        if ($vmgrab.count -eq 0)
        {
            if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { Get-AGMErrorMessage -messagetoprint "There are no managed System State or VMware apps to list" }
            if ($userselectionapps -eq 2)  { Get-AGMErrorMessage -messagetoprint "There are no unmanaged System State or VMware apps to list" }
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
                Write-Host -Object "$i`: $($vm.appname) ($($vm.apptype) AppID $($vm.id)) on $($vm.cluster.name)"
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
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appname to a unique valid VMBackup or System State app.  Use Get-AGMLibApplicationID and try again specifying -appid"
            return
        }
        else {
            $appid = $appgrab.id
        }
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
    if ((!($imagename)) -and ($imageid))
    {
        $imagegrab = Get-AGMImage -id $imageid
        if ($imagegrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find imagename using:  Get-AGMImage -id $imageid"
            return
        }
        else 
        {
            $imagename = $imagegrab.backupname
        }
    }

    # this if for guided menu
    if ($guided)
    {
        if (!($imagename))
        {
            # prefered sourcce
            [int]$userselection = ""
            write-host ""
            Write-Host "Prefered source?   Use this to determine which storage pool will be examined to find source images"
            Write-Host "1`: Any source (default)"
            Write-Host "2`: snapshot"
            Write-Host "3`: streamsnap"
            Write-Host "4`: onvault"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-4)"
            if ($userselection -eq 2) {  $preferedsource = "snapshot" }
            if ($userselection -eq 3) {  $preferedsource = "streamsnap" }
            if ($userselection -eq 4) {  $preferedsource = "onvault" }
            write-host ""
            $userselection = ""
            Write-Host "Image selection"
            Write-Host "1`: Use the most recent backup for lowest RPO (default)"
            Write-Host "2`: Select a backup"
            Write-Host ""
            While ($true) 
            {
                [int]$userselection = Read-Host "Please select from this list (1-2)"
                if ($userselection -eq "") { $userselection = 1 }
                if ($userselection -lt 1 -or $userselection -gt2)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-2]"
                } 
                else
                {
                    break
                }
            }
            if ($userselection -eq 1)
            {
                if ($preferedsource -eq "snapshot")
                {
                    $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
                }
                elseif ($preferedsource -eq "streamsnap")
                {
                    $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=StreamSnap" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
                }
                elseif ($preferedsource -eq "onvault")
                {
                    $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
                }
                else 
                {
                    $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
                }
                if ($imagegrab.count -eq 1)
                {   
                    $copygrab = $imagegrab.copies
                    $consistencydate = $imagegrab.consistencydate
                    $jobclass = $imagegrab.jobclass
                    $imagename = ($copygrab | where-object {$_.targetuds -eq $mountapplianceid}).backupname
                    $imageid =  ($copygrab | where-object {$_.targetuds -eq $mountapplianceid}).id 
                    Write-host ""
                    write-host "Found $jobclass imageID $imageid with consistency date: $consistencydate"
                    Write-host ""
                }
                else 
                {
                    if (!($preferedsource))
                    {
                        Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot, StreamSnap or OnVault Image for appid $appid on appliance with clusterID $mountapplianceid"
                    }   
                    else 
                    {
                        Get-AGMErrorMessage -messagetoprint "Failed to fetch a $preferedsource Image for appid $appid on appliance with clusterID $mountapplianceid"
                    } 
                    return
                }
            }
            if ($userselection -eq 2) 
            { 
                write-host "Fetching Image list from AGM"
                if ($preferedsource -eq "snapshot")
                {
                    $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&targetuds=$mountapplianceid"  | select-object -Property backupname,consistencydate,id,targetuds,jobclass,cluster,diskpool,copies | Sort-Object consistencydate
                }
                elseif ($preferedsource -eq "streamsnap")
                {
                    $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=StreamSnap&targetuds=$mountapplianceid"  | select-object -Property backupname,consistencydate,id,targetuds,jobclass,cluster,diskpool,copies | Sort-Object consistencydate
                }
                elseif ($preferedsource -eq "onvault")
                {
                    $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=OnVault&targetuds=$mountapplianceid"  | select-object -Property backupname,consistencydate,id,targetuds,jobclass,cluster,diskpool,copies | Sort-Object consistencydate
                }
                else 
                {
                    $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&targetuds=$mountapplianceid"  | select-object -Property backupname,consistencydate,id,targetuds,jobclass,cluster,diskpool,copies | Sort-Object consistencydate
                }
                if ($imagelist.id.count -eq 0)
                {
                    if (!($preferedsource))
                    {
                        Get-AGMErrorMessage -messagetoprint "Failed to fetch any Images for appid $appid"
                    }
                    else 
                    {
                        Get-AGMErrorMessage -messagetoprint "Failed to fetch any $preferedsource Images for appid $appid"
                    }
                    return
                }
                Clear-Host
                Write-Host "Image list.  Choose based on the best consistency date, location and jobclass"
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
                $copygrab = $imagelist[($imageselection - 1)].copies
                $imagename = ($copygrab | where-object {$_.targetuds -eq $mountapplianceid}).backupname
                $imageid =  ($copygrab | where-object {$_.targetuds -eq $mountapplianceid}).id 
            }
        }
        # system recovery data grab
        write-host "Getting image data"
        $recoverygrab = Get-AGMAPIData -endpoint /backup/$imageid/systemrecovery/$credentialid -timeout 60
        if ($recoverygrab.fields)
        {
            $recoverydata = $recoverygrab.fields
            $projectlist = (($recoverydata | where-object { $_.name -eq "cloudcredentials" }).children | where-object  { $_.name -eq "project" }).choices | sort-object name
            $regionlist = (($recoverydata | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "region" }).choices | sort-object name
            $machinetypelist = (($recoverydata | where-object { $_.name -eq "instancesettings" }).children | where-object  { $_.name -eq "machinetype" }).choices | sort-object name
            $serviceaccountgrab = (($recoverydata | where-object { $_.name -eq "instancesettings" }).children | where-object  { $_.name -eq "serviceaccount" }).currentValue
            $zonelist = (($recoverydata | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | sort-object name
            $selectedproject = ((($recoverydata | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "project" }).choices | where-object { $_.selected -eq $true }).name
            $selectedregion = ((($recoverydata | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "region" }).choices | where-object { $_.selected -eq $true }).name
            $networklist = ((($recoverydata | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | sort-object displayName
            $selectednetwork = (((($recoverydata | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).displayname
        }

        # project name
        if (!($projectname))
        {
            if ($projectlist.name)
            {
                write-host ""
                write-host "Project Name Selection"
                write-host ""
                $i = 1
                foreach ($project in $projectlist.name)
                { 
                    Write-Host -Object "$i`: $project"
                    $i++
                }
                While ($true) 
                {
                    Write-host ""
                    $listmax = $projectlist.count
                    [int]$projselection = Read-Host "Please select a project (1-$listmax)"
                    if ($projselection -lt 1 -or $projselection -gt $listmax)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                    } 
                    else
                    {
                        break
                    }
                }
                $projectname =  $projectlist.name[($projselection - 1)]
            }
            else {
                While ($true)  { if ($projectname -eq "") { [string]$projectname= Read-Host "Project Name" } else { break } }
            }
            
        }

        # host project ID
        if (!($sharedvpcprojectid))
        {
            write-host ""
            [string]$sharedvpcprojectid= Read-Host "Host Project ID (optional, needed if $projectname is a service project)" 
        }

        # region
        if (!($region))
        {
            if ($regionlist.name)
            {
                write-host ""
                write-host "Region Name Selection"
                write-host ""
                $i = 1
                foreach ($reg in $regionlist.name)
                { 
                    Write-Host -Object "$i`: $reg"
                    $i++
                }
                While ($true) 
                {
                    Write-host ""
                    $listmax = $regionlist.count
                    [int]$rejselection = Read-Host "Please select a region (1-$listmax)"
                    if ($rejselection -lt 1 -or $rejselection -gt $listmax)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                    } 
                    else
                    {
                        break
                    }
                }
                $region =  $regionlist.name[($rejselection - 1)]
            }
            else 
            {
                While ($true)  { if ($region -eq "") { [string]$region= Read-Host "Region" } else { break } }
            }
        }

        #zone
        if (!($zone))
        {
            if ($region -ne $selectedregion)
            {
                $zonelist = ""
                if ($recoverygrab.fields)
                {
                    write-host "Fetching zone list"
                    # we need to send a modified packet backto learn the zones in the users selected region
                    foreach ($row in ($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children)
                    {
                        $row.modified = $false
                    }
                    (($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).modified = $true
                    ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).choices | where-object {$_.selected -eq $true}).selected = $false
                    ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).choices | where-object {$_.name -eq $region}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                    if ($project -ne $selectedproject)
                    {
                        ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "project"}).choices | where-object {$_.name -eq $project}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                    }
                    $recoverygrab | Add-Member -MemberType NoteProperty -Name formtype -Value "newmount"
                    $newjson = $recoverygrab | convertto-json -depth 10 -compress
                    $recoverygrab1 = Put-AGMAPIData -endpoint /backup/$imageid/systemrecovery/$credentialid -body $newjson -timeout 60
                    $recoverydata = $recoverygrab1.fields
                    write-host ""
                    $zonelist = (($recoverydata | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | sort-object name
                    $networklist = ((($recoverydata | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | sort-object displayName
                    $subnetlist = ((($recoverydata | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "subnet" }).choices | sort-object displayName
                    $selectednetwork = (((($recoverydata | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).name
                }
            }
            if ($zonelist)
            {
                write-host ""
                write-host "Zone Name Selection"
                write-host ""
                $i = 1
                foreach ($zon in $zonelist.name)
                { 
                    Write-Host -Object "$i`: $zon"
                    $i++
                }
                While ($true) 
                {
                    Write-host ""
                    $listmax = $zonelist.count
                    [int]$zonselection = Read-Host "Please select a zone (1-$listmax)"
                    if ($zonselection -lt 1 -or $zonselection -gt $listmax)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                    } 
                    else
                    {
                        break
                    }
                }
                $zone =  $zonelist.name[($zonselection - 1)]
            }
            else 
            {
                While ($true)  { if ($zone -eq "") { [string]$zone= Read-Host "Zone" } else { break } }
            }
           
        }

        # learn name of new VM
        if (!($instancename))
        {
            write-host ""
            While ($true)  { if ($instancename -eq "") { [string]$instancename= Read-Host "Name of New VM you want to create using an image of $appname" } else { break } }
        }

        # machine type
        if (!($machinetype))
        {
            if ($machinetypelist.name)
            {
                $displayname  = ($machinetypelist | Where-Object {$_.groupType -eq "Best Fit"}).displayName
                write-host ""
                Write-Host "Machine type selection"
                Write-Host "1`: Use $displayname (default)"
                Write-Host "2`: Select a different type"
                Write-Host ""
                [int]$userselection = Read-Host "Please select from this list (1-2)"
                if ($userselection -eq 2) 
                {
                    write-host ""
                    write-host "Machine Type Selection"
                    write-host ""
                    $i = 1
                    foreach ($machine in $machinetypelist.displayName)
                    { 
                        Write-Host -Object "$i`: $machine"
                        $i++
                    }
                    While ($true) 
                    {
                        Write-host ""
                        $listmax = $machinetypelist.count
                        [int]$machselection = Read-Host "Please select a machine type (1-$listmax)"
                        if ($machselection -lt 1 -or $machselection -gt $listmax)
                        {
                            Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                        } 
                        else
                        {
                            break
                        }
                    }
                    $machinetype =  $machinetypelist.name[($machselection - 1)]
                }
                else
                {  
                    $machinetype = ($machinetypelist | Where-Object {$_.groupType -eq "Best Fit"}).name 
                }
            }
            else 
            {
                While ($true)  { if ($machinetype -eq "") { [string]$machinetype= Read-Host "Machine Type" } else { break } }
            }
        }

        # service account
        if (!($serviceaccount))
        {
            if ($serviceaccountgrab) 
            { 
                write-host ""
                write-host "Suggested service account is: $serviceaccountgrab" 
            }
            While ($true)  { if ($serviceaccount -eq "") { [string]$serviceaccount= Read-Host "Service Account" } else { break } }
        }
        

        # sole tenant name
        if (!($nodegroup))
        {
            write-host ""
            [string]$nodegroup= Read-Host "Sole Tenant Name or Node Group (optional, needed if mounting into a Node Group)" 
        }

        #network tags
        if (!($networktags))
        {
            write-host ""
            [string]$networktags= Read-Host "Network tags (optional)" 
        }

        # poweroff after recovery
        [int]$userselection = ""
        write-host ""
        Write-Host "Power off after recovery?"
        Write-Host "1`: Do not power off after recovery (default)"
        Write-Host "2`: Power off after recovery"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq 2) {  $poweroffvm = $TRUE  }

        # migrate VM
        [int]$userselection = ""
        write-host ""
        Write-Host "Migrate VM?"
        Write-Host "1`: Do not migrate VM (default)"
        Write-Host "2`: Migrate the VM to Persistent Disk"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq 2) {  [switch]$migratevm = $TRUE }

        # labels
        if (!($labels))
        {
            write-host ""
            [string]$labels= Read-Host "Labels (optional).  Separate key and value  with colon, and each pair with a comma, for instance:   pet:cat,food:fish" 
        }


        #networks

        write-host ""
        Write-Host "Network Interfaces?"
        Write-Host "1`: One Nic (default)"
        Write-Host "2`: Two Nics"
        Write-Host ""
        [int]$niccount = Read-Host "Please select from this list (1-2)"
     
        write-host ""
        Write-host "NIC0 settings"
        Write-Host ""


        if ($networklist.name)
        {
            write-host ""
            write-host "Network Selection"
            write-host ""
            $i = 1
            foreach ($net in $networklist.displayName)
            { 
                Write-Host -Object "$i`: $net"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $networklist.count
                [int]$netselection = Read-Host "Please select a network (1-$listmax)"
                if ($netselection -lt 1 -or $netselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            if  ($networklist.name.count -eq 1)
            {
                $nic0network = $networklist.name
            } else {
                $nic0network = $networklist.name[($netselection - 1)]
            }
        }
        else 
        {
            While ($true)  { if ($nic0network -eq "") { [string]$nic0network = Read-Host "NIC0 Network ID (mandatory)" } else { break } }
        }
        # if the network changes then the subnets will change
        if ($nic0network -ne $selectednetwork)
        {
            if ($recoverygrab1.fields)
            {
                write-host "Fetching subnet list"
                # we need to send a modified packet backto learn the subnets in the users selected network
                (((($recoverygrab1.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).selected = $false
                (((($recoverygrab1.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.name -eq $true }) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                $newjson = $recoverygrab1 | convertto-json -depth 10 -compress
                $recoverygrab2 = Put-AGMAPIData -endpoint /backup/$imageid/systemrecovery/$credentialid -body $newjson -timeout 60
                $recoverydata = $recoverygrab2.fields
                write-host ""
                $zonelist = (($recoverydata | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | sort-object name
                $subnetlist = ((($recoverydata | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "subnet" }).choices | sort-object displayName
            }
            else 
            {
                write-host "Fetching subnet list"
                # we need to send a modified packet backto learn the subnets in the users selected network
                foreach ($row in ($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children)
                {
                    $row.modified = $false
                }
                (($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).modified = $true
                ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).choices | where-object {$_.selected -eq $true}).selected = $false
                ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).choices | where-object {$_.name -eq $region}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                if ($project -ne $selectedproject)
                {
                    ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "project"}).choices | where-object {$_.name -eq $project}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                }
                (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).selected = $false
                (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.name -eq $true }) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                $recoverygrab | Add-Member -MemberType NoteProperty -Name formtype -Value "newmount"
                $newjson = $recoverygrab | convertto-json -depth 10 -compress
                $recoverygrab1 = Put-AGMAPIData -endpoint /backup/$imageid/systemrecovery/$credentialid -body $newjson -timeout 60
                $recoverydata = $recoverygrab1.fields
                write-host ""
                $subnetlist = ((($recoverydata | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "subnet" }).choices | sort-object displayName
            }
        }
        if ($subnetlist.name)
        {
            write-host ""
            write-host "Subnet Selection"
            write-host ""
            $i = 1
            foreach ($sub in $subnetlist.displayName)
            { 
                Write-Host -Object "$i`: $sub"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $subnetlist.name.count
                [int]$subselection = Read-Host "Please select a network (1-$listmax)"
                if ($subselection -lt 1 -or $subselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            if  ($subnetlist.name.count -eq 1)
            {
                $nic0subnet = $subnetlist.name
            } else {
                $nic0subnet = $subnetlist.name[($subselection - 1)]
            }
        }
        else 
        {
            While ($true)  { if ($nic0subnet -eq "") { [string]$nic0subnet = Read-Host "NIC0 Subnet ID (mandatory)" } else { break } }
        }
        [int]$userselection = ""
        Write-Host "NIC0 External IP?"
        Write-Host "1`: None (default)"
        Write-Host "2`: Auto Assign"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq 2) {  [string]$nic0externalip = "auto" }
        [int]$userselection = ""
        Write-Host ""
        Write-Host "NIC0 Internal IP?"
        Write-Host "1`: Auto Assign (default)"
        Write-Host "2`: Manual Assign"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq 2) { [string]$nic0internalip = Read-Host "IP address" }

        if ($niccount -eq 2)
        {
            write-host ""
            Write-host "NIC1 settings"
            Write-Host ""
            if ($networklist.name)
            {
                write-host ""
                write-host "Network Selection"
                write-host ""
                $i = 1
                foreach ($net in $networklist.displayName)
                { 
                    Write-Host -Object "$i`: $net"
                    $i++
                }
                While ($true) 
                {
                    Write-host ""
                    $listmax = $networklist.count
                    [int]$netselection = Read-Host "Please select a network (1-$listmax)"
                    if ($netselection -lt 1 -or $netselection -gt $listmax)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                    } 
                    else
                    {
                        break
                    }
                }
                if  ($networklist.name.count -eq 1)
                {
                    $nic1network = $networklist.name
                } else {
                    $nic1network = $networklist.name[($netselection - 1)]
                }
            }
            else 
            {
                While ($true)  { if ($nic1network -eq "") { [string]$nic1network = Read-Host "NIC1 Network ID (mandatory)" } else { break } }
            }
            if ($recoverygrab1.fields)
            {
                write-host "Fetching subnet list"
                # we need to send a modified packet backto learn the subnets in the users selected network
                (((($recoverygrab1.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).selected = $false
                (((($recoverygrab1.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.name -eq $true }) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                $newjson = $recoverygrab1 | convertto-json -depth 10 -compress
                $recoverygrab2 = Put-AGMAPIData -endpoint /backup/$imageid/systemrecovery/$credentialid -body $newjson -timeout 60
                $recoverydata = $recoverygrab2.fields
                write-host ""
                $zonelist = (($recoverydata | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | sort-object name
                $subnetlist = ((($recoverydata | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "subnet" }).choices | sort-object displayName
            }
            else 
            {
                write-host "Fetching subnet list"
                # we need to send a modified packet backto learn the subnets in the users selected network
                foreach ($row in ($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children)
                {
                    $row.modified = $false
                }
                (($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).modified = $true
                ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).choices | where-object {$_.selected -eq $true}).selected = $false
                ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).choices | where-object {$_.name -eq $region}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                if ($project -ne $selectedproject)
                {
                    ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "project"}).choices | where-object {$_.name -eq $project}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                }
                (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).selected = $false
                (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.name -eq $true }) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                $recoverygrab | Add-Member -MemberType NoteProperty -Name formtype -Value "newmount"
                $newjson = $recoverygrab | convertto-json -depth 10 -compress
                $recoverygrab1 = Put-AGMAPIData -endpoint /backup/$imageid/systemrecovery/$credentialid -body $newjson -timeout 60
                $recoverydata = $recoverygrab1.fields
                write-host ""
                $subnetlist = ((($recoverydata | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "subnet" }).choices | sort-object displayName
            }
        
            if ($subnetlist.name)
            {
                write-host ""
                write-host "Subnet Selection"
                write-host ""
                $i = 1
                foreach ($sub in $subnetlist.displayName)
                { 
                    Write-Host -Object "$i`: $sub"
                    $i++
                }
                While ($true) 
                {
                    Write-host ""
                    $listmax = $subnetlist.name.count
                    [int]$sub1selection = Read-Host "Please select a network (1-$listmax)"
                    if ($sub1selection -lt 1 -or $sub1selection -gt $listmax)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                    } 
                    else
                    {
                        break
                    }
                }
                if  ($subnetlist.name.count -eq 1)
                {
                    $nic1subnet = $subnetlist.name
                } else {
                    $nic1subnet = $subnetlist.name[($sub1selection - 1)]
                }
            }
            else 
            {
                While ($true)  { if ($nic0subnet -eq "") { [string]$nic0subnet = Read-Host "NIC0 Subnet ID (mandatory)" } else { break } }
            }
            [int]$userselection = ""
            Write-Host "NIC1 External IP?"
            Write-Host "1`: None (default)"
            Write-Host "2`: Auto Assign"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq 2) {  [string]$nic1externalip = "auto" }
            [int]$userselection = ""
            Write-Host ""
            Write-Host "NIC1 Internal IP?"
            Write-Host "1`: Auto Assign (default)"
            Write-Host "2`: Manual Assign"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq 2) { [string]$nic1internalip = Read-Host "IP address" }
        }

        #disk selection
        $volumelist = ($recoverydata | where-object { $_.name -eq "volumes" })


        if ($volumelist)
        {
            if (!($disktype))
            {
                Write-Host ""
                Write-Host "Disk type Selection"
                Write-Host "1`: pd-balanced (default)"
                Write-Host "2`: pd-extreme"
                Write-Host "3`: pd-ssd"
                Write-Host "4`: pd-standard"
                Write-Host ""
                [int]$diskselection = Read-Host "Please select from this list (1-4)"
                if ($diskselection -eq "") { $diskselection -eq 1 }
                if ($diskselection -eq 1) { $disktype = "pd-balanced" }
                if ($diskselection -eq 2) { $disktype = "pd-extreme" }
                if ($diskselection -eq 3) { $disktype = "pd-ssd" }
                if ($diskselection -eq 4) { $disktype = "pd-standard" }
            }

            foreach ($row in ($volumelist.children.rows.disktype)) {
                if ($row.selected -eq "True")
                {
                    $row.selected = ""
                }
            }
            foreach ($row in ($volumelist.children.rows.disktype)) {
                if ($row.name -eq $disktype)
                {
                    $row | Add-Member -MemberType NoteProperty -Name selected -Value "true"
                }
            }
            $diskjson = $volumelist | ConvertTo-json -depth 10 -compress
        }
        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline "New-AGMLibGCEConversion -srcid $srcid -imageid $imageid -appid $appid -projectname `"$projectname`""
        if ($sharedvpcprojectid) { Write-Host -nonewline " -sharedvpcprojectid `"$sharedvpcprojectid`"" } 
        Write-Host -nonewline " -region `"$region`" -zone `"$zone`" -instancename `"$instancename`" -machinetype `"$machinetype`" -serviceaccount `"$serviceaccount`""
        if ($nodegroup) { Write-Host -nonewline " -nodegroup `"$nodegroup`"" } 
        if ($networktags) { Write-Host -nonewline " -networktags `"$networktags`"" } 
        if ($poweroffvm) { Write-Host -nonewline " -poweroffvm" }
        if ($migratevm) { Write-Host -nonewline " -migratevm" }
        if ($labels) { Write-Host -nonewline " -labels `"$labels`"" } 
        if ($nic0network) { Write-Host -nonewline " -nic0network `"$nic0network`""}
        if ($nic0subnet) { Write-Host -nonewline " -nic0subnet `"$nic0subnet`""}
        if ($nic0externalip) { Write-Host -nonewline " -nic0externalip `"$nic0externalip`""}
        if ($nic0internalip) { Write-Host -nonewline " -nic0internalip `"$nic0internalip`""}
        if ($nic1network) { Write-Host -nonewline " -nic1network `"$nic1network`""}
        if ($nic1subnet) { Write-Host -nonewline " -nic1subnet `"$nic1subnet`""}
        if ($nic1externalip) { Write-Host -nonewline " -nic1externalip `"$nic1externalip`""}
        if ($nic1internalip) { Write-Host -nonewline " -nic1internalip `"$nic1internalip`""}
        if ($preferedsource) { Write-Host -nonewline " -preferedsource `"$preferedsource`""}
        if ($disktype) { Write-Host -nonewline " -disktype `"$disktype`""}
        Write-Host ""
        Write-Host "1`: Run the command now (default)"
        Write-Host "2`: Show the JSON used to run this command, but don't run it"
        Write-Host "3`: Write comma separated output"
        Write-Host "4`: Exit without running the command"
        $userchoice = Read-Host "Please select from this list (1-4)"
        if ($userchoice -eq 2)
        {
            $jsonprint = "yes"
        }
        if ($userchoice -eq 4)
        {
            return
        }
        if ($userchoice -eq 3)
        {
            write-host "srcid,appid,projectname,sharedvpcprojectid,region,zone,instancename,machinetype,serviceaccount,nodegroup,networktags,poweroffvm,migratevm,labels,nic0network,nic0subnet,nic0externalip,nic0internalip,nic1network,nic1subnet,nic1externalip,nic1internalip,preferedsource,disktype"
            write-host -nonewline "$srcid,$appid,`"$projectname`",`"$sharedvpcprojectid`",`"$region`",`"$zone`",`"$instancename`",`"$machinetype`",`"$serviceaccount`",`"$nodegroup`",`"$networktags`","
            if ($poweroffvm) { Write-Host -nonewline "true," }
            if ($migratevm) { Write-Host -nonewline "true," }
            write-host -nonewline "$labels,$nic0network,$nic0subnet,"
            if ($nic0externalip) { Write-Host -nonewline $nic0externalip }
            write-host -nonewline ",$nic0internalip,$nic1network,$nic1subnet,"
            if ($nic1externalip) { Write-Host -nonewline $nic1externalip }
            write-host -nonewline ",$nic1internalip,$preferedsource,$disktype"
            write-host ""
            return
        }

    }

    # if we are not running guided mode, but the user has supplied a srcid and appid then we need to find the latest image either in any storage class or user selected class
    if (($appid) -and ($srcid) -and (!($imageid)))
    {
        # if we don't know the mountapplianceID then we don't know which appliance to kick this off from
        $credgrab = Get-AGMLibCredentialSrcID | Where-Object {$_.srcid -eq $srcid}
        if ($credgrab.appliancename.count -eq 1)
        {
            $mountapplianceid = $credgrab.applianceid
            $credentialid = $credgrab.credentialid
        }  else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to learn the credentialid of srcid $srcid.  Please validate your srcid with: Get-AGMLibCredentialSrcID"
            return
        }

        # if we are not running guided mode but we have an appid without imageid, then lets get the latest image on the mountappliance ID
       
        if ($preferedsource -eq "snapshot")
        {
            $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
        }
        elseif ($preferedsource -eq "streamsnap")
        {
            $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=StreamSnap" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
        }
        elseif ($preferedsource -eq "onvault")
        {
            $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
        }
        else 
        {
            $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
        }
        if ($imagegrab.count -eq 1)
        {   
            $copygrab = $imagegrab.copies
            $imagename = ($copygrab | where-object {$_.targetuds -eq $mountapplianceid}).backupname
            $imageid =  ($copygrab | where-object {$_.targetuds -eq $mountapplianceid}).id 
        }
        else 
        {
            if (!($preferedsource))
            {
                Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot, StreamSnap or OnVault Image for appid $appid on appliance with clusterID $mountapplianceid"
            }   
            else 
            {
                Get-AGMErrorMessage -messagetoprint "Failed to fetch a $preferedsource Image for appid $appid on appliance with clusterID $mountapplianceid"
            } 
            return
        }
        if ($disktype)
        {
            $recoverygrab = Get-AGMAPIData -endpoint /backup/$imageid/systemrecovery/$credentialid -timeout 60
            if ($recoverygrab.fields)
            {
                $recoverydata = $recoverygrab.fields
            }
            #disk selection
            $volumelist = ($recoverydata | where-object { $_.name -eq "volumes" }) 

            if ($volumelist)
            {
                foreach ($row in ($volumelist.children.rows.disktype)) {
                    if ($row.selected -eq "True")
                    {
                        $row.selected = ""
                    }
                }
                foreach ($row in ($volumelist.children.rows.disktype)) {
                    if ($row.name -eq $disktype)
                    {
                        $row | Add-Member -MemberType NoteProperty -Name selected -Value "true"
                    }
                }
                $diskjson = $volumelist | ConvertTo-json -depth 10 -compress
            }
        }
    }

    # if we didnt run guided mode then complain about missing fields, no interaction here
    if (!($srcid))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a credential src ID for the new instance with -srcid.  Learn this with Get-AGMCredential"
        return
    }
    if (!($projectname))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a project for the new instance with -projectname"
        return
    }
    if (!($region))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a region for the new instance with -region"
        return
    }
    if (!($zone))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a zone for the new instance with -zone"
        return
    }
    if (!($instancename))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a name for the new instance with -instancename"
        return
    }
    if (!($machinetype))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a machinetype for the new instance with -machinetype"
        return
    }
   if (!($nic0network))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a network for nic0 for the new instance with -nic0network"
        return
    }
    if (!($nic0subnet))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a subnet for nic0 for the new instance with -nic0subnet"
        return
    }
    # optionally check nic1
    if ((!($nic1network)) -and ($nic1subnet))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a network for nic1 for the new instance with -nic1network"
        return
    }
    if ((!($nic1subnet)) -and ($nic1network))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a subnet for nic1 for the new instance with -nic1subnet"
        return
    }

    # we need a credential ID to grab diskjson, so if we dont have one here, grab it
    if (!($credentialid))
    {
        $credgrab = Get-AGMLibCredentialSrcID | Where-Object {$_.srcid -eq $srcid}
        if ($credgrab.appliancename.count -eq 1)
        {
            $mountapplianceid = $credgrab.applianceid
            $credentialid = $credgrab.credentialid
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to learn the credentialid of srcid $srcid.  Please validate your srcid with: Get-AGMLibCredentialSrcID"
            return
        }
    }

    # we need to build diskjson
    if (!($diskjson))
    {
        if (!($disktype))
        {
            $disktype = "pd-balanced"
        }
        $recoverygrab = Get-AGMAPIData -endpoint /backup/$imageid/systemrecovery/$credentialid -timeout 60
        if ($recoverygrab.fields)
        {
            $recoverydata = $recoverygrab.fields
            $volumelist = ($recoverydata | where-object { $_.name -eq "volumes" })
            foreach ($row in ($volumelist.children.rows.disktype)) {
                if ($row.selected -eq "True")
                {
                    $row.selected = ""
                }
            }
            foreach ($row in ($volumelist.children.rows.disktype)) {
                if ($row.name -eq $disktype)
                {
                    $row | Add-Member -MemberType NoteProperty -Name selected -Value "true" -force
                }
            }
            $diskjson = $volumelist | ConvertTo-json -depth 10 -compress
        }
    }



    # Now we built the JSON
    # cloud credentials
    $json = '{"cloudvmoptions":{"@type":"cloudVmMountRest","fields":[{"displayName":"","name":"cloudcredentials","helpId":1014,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"CLOUD CREDENTIALS NAME","name":"cloudcredential","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"credentialname","name":"' +$srcid +'","selected":true}],"_getchoices":"getCloudCredentials#cloudcredentiallist,image","_dependent":["project","region","zone","machinetype","vpc","subnet","privateips","externalip"],"disabled":true,"hidden":true},'
    # project name
    $json = $json + '{"displayName":"PROJECT NAME","name":"project","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"projectname","name":"' +$projectname +'","selected":true}],"_getchoices":"getAllProjects#handle,cloudcredential","_dependent":["region","zone","machinetype","vpc","subnet","privateips","externalip"]},'
    # host project name
    if ($sharedvpcprojectid)
    {
        $json = $json + '{"displayName":"HOST PROJECT ID","name":"hostprojectid","helpId":1014,"type":"text","description":"SharedVPC Host Project ID","currentValue":"' +$sharedvpcprojectid +'","modified":true,"size":80},'
    }
    else 
    {
        $json = $json + '{"displayName":"HOST PROJECT ID","name":"hostprojectid","helpId":1014,"type":"text","description":"SharedVPC Host Project ID","currentValue":"","modified":false,"size":80},'
    }
    #region
    $json = $json + '{"displayName":"REGION","name":"region","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"regionname","name":"' +$region +'","selected":true}],"_getchoices":"getRegions#handle,cloudcredential","_dependent":["zone","machinetype","vpc","subnet","privateips","externalip"]},'
    # zone
    $json = $json + '{"displayName":"ZONE","name":"zone","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"zonename","name":"' +$zone +'","selected":true}],"_getchoices":"getZonesPerRegion#handle,cloudcredential,region","_dependent":["machinetype","vpc","subnet","privateips","externalip"]}],"groupType":"layout"},{"displayName":"","name":"instancesettings","helpId":1014,"type":"group","description":"","required":true,"modified":false,"children":['
    #instance name
    $json = $json + '{"displayName":"INSTANCE NAME","name":"instancename","helpId":1014,"type":"text","description":"","required":true,"modified":false,"size":40,"_getDefault":"getDefaultInstanceName","currentValue":"' +$instancename +'"},'
    $json = $json + '{"displayName":"MACHINE TYPE","name":"machinetype","helpId":1014,"type":"dropdown","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"machinetype","name":"' +$machinetype +'","selected":true,"groupType":"Best Fit"}],"_getchoices":"getMachineTypes#handle,cloudcredential,region,project,zone","_dependent":["networksettings"],"groupBy":true},' 
    #service account
    $json = $json + '{"displayName":"SERVICE ACCOUNT","name":"serviceaccount","helpId":1014,"type":"text","description":"","required":true,"currentValue":"' +$serviceaccount +'","modified":false,"size":40,"_getDefault":"getDefaultServiceAccount"},'
    # sole tenant name
    if ($nodegroup)
    {
        $json = $json + '{"displayName":"SOLE TENANT NAME","name":"soletenantname","helpId":1014,"type":"text","description":"Sole tenant group name","currentValue":"' +$nodegroup +'","modified":true,"size":40},'
    }
    else 
    {
        $json = $json + '{"displayName":"SOLE TENANT NAME","name":"soletenantname","helpId":1014,"type":"text","description":"Sole tenant group name","currentValue":"","modified":false,"size":40},'
    }
    if (!($networktags))
    {
        $json = $json + '{"displayName":"NETWORK TAGS","name":"networktag","helpId":1014,"type":"text","description":"","currentValue":"","modified":false,"size":100},'
    } 
    else 
    {
        $json = $json + '{"displayName":"NETWORK TAGS","name":"networktag","helpId":1014,"type":"text","description":"","currentValue":"' +$networktags +'","modified":true,"size":100},'
    }
    # power off after recovery
    if ($poweroffvm -eq $true)
    {
        $json = $json + '{"displayName":"POWER OFF AFTER RECOVERY","name":"poweroffvm","helpId":1014,"type":"checkbox","description":"","modified":true,"checked":true},'
    }
    else 
    {
        $json = $json + '{"displayName":"POWER OFF AFTER RECOVERY","name":"poweroffvm","helpId":1014,"type":"checkbox","description":"","modified":false,"checked":false},'
    }

    # migrate VM
    if ($migratevm -eq $true)
    {
        $json = $json + '{"displayName":"MIGRATE VM","name":"migratevm","helpId":1014,"type":"checkbox","description":"Migrate VM","modified":false,"dynamic":true,"_dependent":["volumeselection"],"checked":true}],"groupType":"layout"},{"displayName":"","name":"tagsgroup","helpId":1014,"type":"group","description":"","required":true,"modified":false,"children":['
    }
    else 
    {
        $json = $json + '{"displayName":"MIGRATE VM","name":"migratevm","helpId":1014,"type":"checkbox","description":"Migrate VM","modified":false,"dynamic":false,"_dependent":["volumeselection"],"checked":false}],"groupType":"layout"},{"displayName":"","name":"tagsgroup","helpId":1014,"type":"group","description":"","required":true,"modified":false,"children":['
    }
    # labels
    if ($labels)
    {
        $json = $json + '{"displayName":"Labels","name":"tag","helpId":1014,"type":"tagselection","description":"","modified":true,"minimum":1,"maximum":50,"choices":['
        $labelgroup = ""
        foreach ($label in $labels.Split(","))
        {   
            $key = $label.Split(":") | Select-object -First 1
            $value = $label.Split(":") | Select-object -skip 1
            $labelgroup = $labelgroup + '{"selected":true,"key":"' +$key +'","value":"' +$value +'"},'   
        }
        $json = $json + $labelgroup.TrimEnd(",")
        $json = $json + '],"validation":""}],"groupType":"layout"},'
    }
    else 
    {
        $json = $json + '{"displayName":"Labels","name":"tag","helpId":1014,"type":"tagselection","description":"","modified":false,"minimum":1,"maximum":50,"choices":[],"validation":""}],"groupType":"layout"},'
    }
    # network starter
     $json = $json + '{"displayName":"Network Interfaces","name":"networksettings","helpId":1014,"type":"networkinterfaces","description":"","required":true,"modified":false,"minimum":1,"maximum":2,"children":['
    # nic0 BEGIN
    #network name
     $json = $json + '{"displayName":"NIC0","name":"nic0","helpId":1014,"type":"nic","description":"","required":true,"modified":false,"children":[{"displayName":"NETWORK","name":"vpc","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic0network +'","selected":true}],"_getchoices":"getVpcs#handle,cloudcredential,region,project,resourcegroup,zone","_dependent":["subnet","privateips"],"parentName":"nic0"},'
    #subnet name
     $json = $json + '{"displayName":"SUBNET","name":"subnet","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic0subnet +'","selected":true}],"_getchoices":"getSubnets#handle,cloudcredential,region,vpc,project,zone","_dependent":["privateips"],"parentName":"nic0"},'
     #nic0 external (default is none)
    if ($nic0externalip -eq "auto")
    {
        $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0","selected":true},{"displayName":"None","name":"None"}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","parentName":"nic0"},'
    }
    else 
    {
        $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"choices":[{"displayName":"None","name":"None","selected":true}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","parentName":"nic0"},'
    }
    # internal IP   The default is auto
    if ($nic0internalip)
    {
        $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1014,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1014,"type":"radiobutton","checked":false,"parentName":"nic0","modified":false},{"displayName":"Manual Assign","name":"internalipassign","helpId":1014,"type":"radiobutton","checked":true,"parentName":"nic0","modified":true},{"name":"privateips","helpId":1014,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":["' +$nic0internalip +'"],"disabled":true,"validation":"0.0.0.0/0","parentName":"nic0"}],"parentName":"nic0"}]}'
    }
    else
    {
        $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1014,"type":"internalipaddress","description":"","modified":false,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1014,"type":"radiobutton","modified":false,"checked":true,"parentName":"nic0"},{"displayName":"Manual Assign","name":"internalipassign","helpId":1014,"type":"radiobutton","modified":false,"checked":false,"parentName":"nic0"},{"name":"privateips","helpId":1014,"type":"ipaddress","modified":false,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":[],"disabled":true,"validation":"0.0.0.0/0","parentName":"nic0"}],"parentName":"nic0"}]}'
    }
     # NIC1 BEGIN 
     if (($nic1network) -and ($nic1subnet)) 
     {
        # NIC1 network
        $json = $json + ',{"displayName":"NIC1","name":"nic1","helpId":1014,"type":"nic","description":"","required":true,"modified":true,"children":[{"displayName":"NETWORK","name":"vpc","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"networkname","name":"' +$nic1network +'","selected":true}],"_getchoices":"getVpcs#handle,cloudcredential,region,project,resourcegroup,zone","_dependent":["subnet","privateips"],"parentName":"nic1"},'
        # NIC1 subnet
        $json = $json + '{"displayName":"SUBNET","name":"subnet","helpId":1014,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"australia (australia)","name":"' +$nic1subnet +'","selected":true}],"_getchoices":"getSubnets#handle,cloudcredential,region,vpc,project,zone","_dependent":["privateips"],"parentName":"nic1"},'
        #nic1 external
        if ($nic1externalip -eq "auto")
        {  
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0","selected":true],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","parentName":"nic1"},'
        }
        else 
        {
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1014,"type":"selection","description":"","required":true,"modified":false,"choices":[{"displayName":"None","name":"None","selected":true}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","parentName":"nic1"},'
        }
        #nic1 internal
        if ($nic1internalip)
        {   
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1014,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1014,"type":"radiobutton","modified":false,"checked":false,"parentName":"nic1"},{"displayName":"Manual Assign","name":"internalipassign","helpId":1014,"type":"radiobutton","modified":false,"checked":true,"parentName":"nic1"},{"name":"privateips","helpId":1014,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":["' +$nic1internalip +'"],"disabled":true,"validation":"0.0.0.0/20","parentName":"nic1"}],"parentName":"nic1"}]}' 
        }
        else 
        {
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1014,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1014,"type":"radiobutton","modified":false,"checked":true,"parentName":"nic1"},{"name":"privateips","helpId":1014,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":[],"disabled":true,"validation":"10.186.0.0/20","parentName":"nic1"}],"parentName":"nic1"}]}'
 
        }
    }
    # NETWORK ENDS
    $json = $json + '],"groupType":"layout"},'
     # volumes
    if ($diskjson)
    {
        $json = $json + $diskjson
    } 
    else
    {
        # this line might need to be edited to remove the disk row that this is there 
        $json = $json + '{"displayName":"Select Volumes to Mount","name":"volumes","helpId":1014,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"","name":"volumeselection","helpId":1014,"type":"volumeselectiontable","description":"","required":true,"modified":false,"title":"Select Volumes to Mount","header":[{"displayName":"DEVICE NAME","name":"devicename","type":"text"},{"displayName":"CAPACITY","name":"size","type":"text"},{"displayName":"SOURCE MOUNT PATH","name":"sourcemountpath","type":"text"},{"displayName":"UNIQUE ID","name":"volumeid","type":"text"},{"displayName":"VOLUME TYPE","name":"devicetype","type":"text"},{"displayName":"TARGET","name":"deviceindex","type":"text"},{"displayName":"DISK TYPE","name":"disktype","type":"selection"}],"rows":[{"size":"40 GB","volumeid":"vmvol:6000C296-dd6e-9635-bb5f-70f2453cb47a","devicename":"[vsanDatastore] d625b860-bc45-51c1-03f5-0c42a10e6a68/Centos2_1.vmdk","disktype":[{"displayName":"Balanced Persistent Disk(DiskSizeGb: 100)","name":"pd-balanced","selected":true},{"displayName":"Extreme Persistent Disk(DiskSizeGb: 1000)","name":"pd-extreme"},{"displayName":"SSD Persistent Disk(DiskSizeGb: 100)","name":"pd-ssd"},{"displayName":"Standard Persistent Disk(DiskSizeGb: 500)","name":"pd-standard"}],"sourcemountpath":"[vsanDatastore] d625b860-bc45-51c1-03f5-0c42a10e6a68/Centos2_1.vmdk","devicetype":"BOOT","deviceindex":"cloud:6122EAC43B_286","selected":true,"disabled":true,"disktypeDisabled":false}],"_getchoices":"getVolumeTypes#handle,cloudcredential,region,zone,project,machinetype"}],"groupType":"wizard"}'
    }
    # end part
    $json = $json + '],"formtype":"systemrecovery","image":"' +$imagename +'","cloudtype":"GCP"}}'

    # diag info
    # write-host "image name is $imagename and image ID is $imageid and appid is $appid" 
   
    if ($jsonprint -eq "yes")
    {   
        $json  
        return
    }
    # launch the command and check output
    $newgcp = Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json

    if ($newgcp.fields)
    {
        $invalid = (($newgcp.fields | Select-Object children).children | Select-Object invalid).invalid
        Get-AGMErrorMessage -messagetoprint $invalid
    }
    else {
        $newgcp
    }
    
}