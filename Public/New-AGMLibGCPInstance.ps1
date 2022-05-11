Function New-AGMLibGCPInstance ([string]$appid,[string]$appname,[string]$imageid,[string]$imagename,[string]$srcid,[string]$projectname,[string]$zone,[string]$region,[string]$instancename,[string]$machinetype,[string]$disktype,[string]$serviceaccount,[string]$networktags,[string]$labels,[string]$nic0network,[string]$nic0subnet,[string]$nic0externalip,[string]$nic0internalip,[string]$nic1network,[string]$nic1subnet,[string]$nic1externalip,[string]$nic1internalip,[string]$nic2network,[string]$nic2subnet,[string]$nic2externalip,[string]$nic2internalip,[string]$nic3network,[string]$nic3subnet,[string]$nic3externalip,[string]$nic3internalip,[string]$poweronvm,[string]$retainlabel) 
{
    <#
    .SYNOPSIS
    Mounts a PD Snapshot as a new GCP Instance (VM)

    .EXAMPLE
    New-AGMLibGCPInstance -imageid 56410933 -srcid 1234 -zone australia-southeast1-c -projectname myproject -instancename avtest21 -machinetype e2-micro -networktags "http-server,https-server" -labels "dog:cat,sheep:cow" -nic0network "https://www.googleapis.com/compute/v1/projects/projectname/global/networks/default" -nic0subnet "https://www.googleapis.com/compute/v1/projects/projectname/regions/australia-southeast1/subnetworks/default" -nic0externalip auto -nic0internalip "10.152.0.200" -poweronvm false

    This mounts the specified imageid 56410933

    .EXAMPLE
    New-AGMLibGCPInstance -appid 1234 -srcid 1234 -zone australia-southeast1-c -projectname myproject -instancename avtest21 -machinetype e2-micro -networktags "http-server,https-server" -labels "dog:cat,sheep:cow" -nic0network "https://www.googleapis.com/compute/v1/projects/projectname/global/networks/default" -nic0subnet "https://www.googleapis.com/compute/v1/projects/projectname/regions/australia-southeast1/subnetworks/default" -nic0externalip auto -nic0internalip "10.152.0.200" -poweronvm false -disktype pd-ssd

    This mounts the most recent snapshot from appid 1234

    .DESCRIPTION
    To learn which Applications are suitable use this command:
    Get-AGMApplication -filtervalue "apptype=GCPInstance&managed=True" | select id,appname,@{N='appliancename'; E={$_.cluster.name}}

    To learn which Cloud Credential srcids are available use this command:
    Get-AGMLibCredentialSrcID

    To learn the image ID or image name, you could use this command:
    Get-AGMImage -filtervalue "apptype=GCPInstance&jobclass=snapshot" | select appname,id,name,consistencydate,diskpool | ft
    
    There are many parameters that need to be supplied:

    -appid           The application ID of the source GCP Instance you want to mount.  If you use this you don't need to specify an image ID or name.   It will use the latest snapshot of that application.
    -imageid         You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image)
    -imagename       You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image)
    -srcid           Learn this with Get-AGMLibCredentialSrcID.  You need to use the correct srcid that matches the appliance that is protecting the application.
    -serviceaccount  The service account that is being used to request the instance creation.  This is optional.  Otherwise it will use the account from the cloud credential
    -projectname     This is the unique Google Project name
    -region          This is the GCP location such as: australia-southeast1 (used only by Actifio Sky Appliance)
    -zone            This is the GCP Zone such as: australia-southeast1-c
    -instancename    This is the name of the new instance that will be created.   It needs to be unique in that project
    -machinetype     This is the GCP instance machine type such as:  e2-micro
    -networktags     Comma separate as many tags as you have, for instance:   -networktags "http-server,https-server"   
    -labels          Labels are key value pairs.   Separate key and value with colons and each label with commas.   For example:   -labels "pet:cat,food:fish"
    -retainlabel     Specify true and then any labels in the selected image will be retained in the new GCE instance.   Partial label retention is not supported.
                     If a label is specified that already exists in the source VM, then the user specified key value will be prefered over the retained label from the source
    -nic0network     The network name in URL format for nic0
    -nic0subnet      The subnet name in URL format for nic0
    -nic0externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic0 is 'none'
    -nic0internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic0 will be auto assigned.   
    -poweronvm       By default the new GCE Instance will be powered on.   If you want it to be created but left powered off, then specify: -poweronvm false
                     There is no need to specify: -poweronvm true 
  

    Optionally you can request a second, third or fourth NIC using nic1, nic2 or nic3.   nic1 example shown:
    -nic1network     The network name in URL format for nic1
    -nic1subnet      The subnet name in URL format for nic1
    -nic1externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic1 is 'none'
    -nic1internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic1 will be auto assigned.   
 
    Optionally you can specify that all disks be a different type:
    -disktype        Has to be one  of pd-balanced, pd-extreme, pd-ssd, pd-standard   All disks in the instance will use this disk type
    
    What is not supported right now:
    1)  Specifying more than one internal IP per subnet.
    2)  Specifying different disk types per disk
  
    If you are having what look like timeout issues, please run connect-agm with a -agmtimeout value larger than then the default of 60 seconds

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

    #GUIDED MODE kicks in if we dont have an image or app preference
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
        } else
        {
            Clear-Host
            write-host "Welcome to the Guided Menu for GCE Conversion. "
            write-host "You will be offered selections to build a command to run a mount job that will create a new GCE Instance"
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
                } else
                {
                    break
                }
            }
            if ($credarray.credentialid.count -eq 1)
            {
                $srcid = $credarray.srcid
                $mountapplianceid = $credarray.applianceid
                $mountappliancename = $credarray.appliancename
                $credentialid =$credarray.credentialid
            } else 
            {
                $srcid = $credarray.srcid[($credselection - 1)]
                $mountapplianceid = $credarray.applianceid[($credselection - 1)]
                $mountappliancename = $credarray.appliancename[($credselection - 1)]
                $credentialid =$credarray.credentialid[($credselection - 1)]
            }
        }

        Write-host ""
        Write-host ""
        write-host "Select application status for GCPInstance apps with images on $mountappliancename"
        Write-host ""
        Write-Host "1`: Managed local apps (default)"
        Write-Host "2`: Unmanaged local apps"
        Write-Host "3`: Imported/mirrored apps (from other Appliances).  If you cannot see imported apps, you may need to first run:  Import-AGMLibPDSnapshot"
        Write-Host ""
        [int]$userselectionapps = Read-Host "Please select from this list (1-3)"
        if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { $vmgrab = Get-AGMApplication -filtervalue "managed=true&apptype=GCPInstance&sourcecluster=$mountapplianceid" | sort-object appname }
        if ($userselectionapps -eq 2) { $vmgrab = Get-AGMApplication -filtervalue "managed=false&apptype=GCPInstance&sourcecluster=$mountapplianceid" | sort-object appname  }
        if ($userselectionapps -eq 3) { $vmgrab = Get-AGMApplication -filtervalue "apptype=GCPInstance&sourcecluster!$mountapplianceid&clusterid=$mountapplianceid" | sort-object appname }
        if ($vmgrab.count -eq 0)
        {
            if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { Get-AGMErrorMessage -messagetoprint "There are no managed GCPInstance apps to list" }
            if ($userselectionapps -eq 2)  { Get-AGMErrorMessage -messagetoprint "There are no unmanaged GCPInstance apps to list" }
            if ($userselectionapps -eq 3)  { Get-AGMErrorMessage -messagetoprint "There are no imported GCPInstance apps to list.  You may need to run Import-AGMLibPDSnapshot first" }
            return
        }
        
        write-host ""
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
        if ($vmgrab.id.count -eq 1)
        {
            $appname =  $vmgrab.appname
            $appid = $vmgrab.id
        }
        else {
            $appname =  $vmgrab.appname[($vmselection - 1)]
            $appid = $vmgrab.id[($vmselection - 1)]
        }
    }

    if ( ($appname) -and (!($appid)) )
    {
        $appgrab = Get-AGMApplication -filtervalue "appname=$appname&apptype=GCPInstance"
        if ($appgrab.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appname to a unique valid GCE Instance app.  Use Get-AGMLibApplicationID and try again specifying -appid"
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
                if ($userselection -lt 1 -or $userselection -gt 2)
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

                $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
                
                if ($imagegrab.id.count -eq 1)
                {   
                    $consistencydate = $imagegrab.consistencydate
                    $jobclass = $imagegrab.jobclass
                    $imagename = $imagegrab.backupname
                    $imageid =  $imagegrab.id 
                    Write-host ""
                    write-host "Found $jobclass imageID $imageid with consistency date: $consistencydate"
                    Write-host ""
                }
                else 
                {
                    Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot for appid $appid on appliance with clusterID $mountapplianceid"   
                    return
                }
            }
            if ($userselection -eq 2) 
            { 
                write-host "Fetching Image list from AGM"
                $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&targetuds=$mountapplianceid"  | select-object -Property backupname,consistencydate,id,targetuds,jobclass,cluster,diskpool | Sort-Object consistencydate
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
                Write-Host "Image list.  Choose based on the best consistency date and location"
                $i = 1
                foreach
                ($image in $imagelist)
                { 
                    $target = $image.cluster.name
                    Write-Host -Object "$i`:  $($image.consistencydate) (Appliance: $target)"
                    $i++
                }
                While ($true) 
                {
                    Write-host ""
                    $listmax = $imagelist.id.count
                    [int]$imageselection = Read-Host "Please select an image (1-$listmax)"
                    if ($imageselection -lt 1 -or $imageselection -gt $listmax)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                    } 
                    else
                    {
                        break
                    }
                }
                if ($imagelist.id.count -eq 1)
                {
                    $imagename = $imagelist.backupname
                    $imageid =  $imagelist.id 
                }
                else {
                    $imagename = $imagelist[($imageselection - 1)].backupname
                    $imageid =  $imagelist[($imageselection - 1)].id 
                }
            }
        }
        # system recovery data grab
        write-host "Getting image data"
        # we get this blindly without specifying cloud credential
        $recoverygrab = Get-AGMAPIData -endpoint /backup/$imageid/mount -extrarequests "&formtype=newmount"
        if ($recoverygrab.fields)
        {
            # if the selected credential doesnt equal the user chosen one we need to relearn
            $selectedcredential = ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "cloudcredential" }).choices | where-object { $_.selected -eq $true }).name
            if ($selectedcredential -ne $srcid)
            {
                write-host "Fetching selection data for srcid $srcid"
                write-host ""
                # the first thing to check is to grab the data weith correct srcid
                ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "cloudcredential" }).choices | where-object { $_.selected -eq $true }).selected = $false
                ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "cloudcredential"}).choices | where-object {$_.name -eq $srcid}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                $recoverygrab.PSObject.Properties.Remove('@type')
                $recoverygrab | Add-Member -MemberType NoteProperty -Name formtype -Value "existingmount"
                $newjson = $recoverygrab | convertto-json -depth 10 -compress
                $recoverygrab = Put-AGMAPIData -endpoint /backup/$imageid/mount -body $newjson 
            }
            #now read the data
            $projectlist = (($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children | where-object  { $_.name -eq "project" }).choices | sort-object name
            $machinetypelist = (($recoverygrab.fields | where-object { $_.name -eq "instancesettings" }).children | where-object  { $_.name -eq "machinetype" }).choices | sort-object name
            $serviceaccountgrab = (($recoverygrab.fields | where-object { $_.name -eq "instancesettings" }).children | where-object  { $_.name -eq "serviceaccount" }).currentValue
            $zonelist = (($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | sort-object name
            $selectedproject = ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "project" }).choices | where-object { $_.selected -eq $true }).name
            $selectedzone = ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | where-object { $_.selected -eq $true }).name
            $networklist = ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | sort-object displayName
            $selectednetwork = (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).displayname
            if (($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "region" })
            {
                $regionlist = (($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "region" }).choices | sort-object name
                $selectedregion =  ($regionlist.choices | where-object {$_.selected -eq $true}).name
            }
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
                if ($projectlist.name.count -eq 1)
                {
                    $projectname = $projectlist.name
                }
                else {
                    $projectname = $projectlist.name[($projselection - 1)]
                }
                # is the selected project changes, we need to relearn the world
                if ($projectname -ne $selectedproject)
                {
                    write-host "Fetching selection data for project $projectname"
                    write-host ""
                    # ensure we are using a different selected project
                    ($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).modified = $true
                    (($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "project"}).modified = $true
                    ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "project" }).choices | where-object { $_.selected -eq $true }).selected = $false
                    ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "project"}).choices | where-object {$_.name -eq $projectname}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                    if (!($recoverygrab.formtype))
                    {
                        $recoverygrab.PSObject.Properties.Remove('@type')
                        $recoverygrab | Add-Member -MemberType NoteProperty -Name formtype -Value "existingmount"
                    }
                    $newjson = $recoverygrab | convertto-json -depth 10 -compress
                    $recoverygrab = Put-AGMAPIData -endpoint /backup/$imageid/mount -body $newjson 
                    $machinetypelist = (($recoverygrab.fields | where-object { $_.name -eq "instancesettings" }).children | where-object  { $_.name -eq "machinetype" }).choices | sort-object name
                    $serviceaccountgrab = (($recoverygrab.fields | where-object { $_.name -eq "instancesettings" }).children | where-object  { $_.name -eq "serviceaccount" }).currentValue
                    $zonelist = (($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | sort-object name
                    $selectedproject = ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "project" }).choices | where-object { $_.selected -eq $true }).name
                    $selectedzone = ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | where-object { $_.selected -eq $true }).name
                    $networklist = ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | sort-object displayName
                    $selectednetwork = (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).displayname
                    if (($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "region" })
                    {
                        $regionlist = (($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "region" }).choices | sort-object name
                        $selectedregion =  ($regionlist.choices | where-object {$_.selected -eq $true}).name
                    }
                }
            } else {
                While ($true)  { if ($projectname -eq "") { [string]$projectname= Read-Host "Project Name" } else { break } }
            }
            
        }
        # region
        if ((!($region)) -and ($regionlist))
        {
            if ($regionlist.name)
            {
 
                # create an array out of the regionlist
                $regionarray = @()
                $i = 1
                foreach ($geo in $regionlist)
                {
                    $geoname = $geo.displayname
                    foreach ($selection in $geo.choices)
                    {
                        $regionarray += [pscustomobject]@{
                            id = $i
                            geo = $geoname
                            region = $selection.name
                        }
                        $i++
                    }
                }
                write-host ""
                write-host "Region Name Selection"
                write-host ""
                $regionarray | Format-Table

                While ($true) 
                {
                    Write-host ""
                    $listmax = $regionarray.count
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
                $region =  $regionarray.region[($rejselection - 1)]
            }
            else 
            {
                While ($true)  { if ($region -eq "") { [string]$region= Read-Host "Region" } else { break } }
            }
        }

        # zone
        if (!($zone))
        { 
            if ($zonelist.name)
            {
                # if region selectio is possible we need to validate we have the right list of zones
                if ($selectedregion)
                {
                    if ($selectedregion -ne $region)
                    {
                        # check this
                        foreach ($row in $recoverygrab.fields)
                        {
                            $row.modified = $false
                        }
                        foreach ($row in ($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children)
                        {
                            $row.modified = $false
                        }
                        # correct region
                        (($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "region"}).modified = $true
                        ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "region" }).choices.choices | where-object {$_.selected -eq $true}).selected = $false
                        ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "region" }).choices.choices | where-object {$_.name -eq $region}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                        if (!($recoverygrab.formtype))
                        {
                            $recoverygrab.PSObject.Properties.Remove('@type')
                            $recoverygrab | Add-Member -MemberType NoteProperty -Name formtype -Value "existingmount"
                        }
                        $newjson = $recoverygrab | convertto-json -depth 10 -compress
                        $recoverygrab = Put-AGMAPIData -endpoint /backup/$imageid/mount -body $newjson 
                        if ($recoverygrab.fields)
                        {
                            $machinetypelist = (($recoverygrab.fields | where-object { $_.name -eq "instancesettings" }).children | where-object  { $_.name -eq "machinetype" }).choices | sort-object name
                            $serviceaccountgrab = (($recoverygrab.fields | where-object { $_.name -eq "instancesettings" }).children | where-object  { $_.name -eq "serviceaccount" }).currentValue
                            $zonelist = (($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | sort-object name
                            $networklist = ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | sort-object displayName
                            $selectednetwork = (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).displayname
                            $subnetlist = ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "subnet" }).choices | sort-object displayName
                            $selectedzone = ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | where-object { $_.selected -eq $true }).name
                        } 
                        else 
                        {
                            Get-AGMErrorMessage -messagetoprint "Failed to learn zone names for selected region."
                            return
                        }
                    }
                }
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
                if ($zone -ne $selectedzone)
                {
                    write-host "Fetching network list for $zone"
                    foreach ($row in $recoverygrab.fields)
                    {
                        $row.modified = $false
                    }
                    foreach ($row in ($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children)
                    {
                        $row.modified = $false
                    }
                    ($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).modified = $true
                    (($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "zone"}).modified = $true
                    foreach ($row in ((($recoverygrab.fields | where-object { $_.name -eq "cloudcredentials" }).children| where-object  { $_.name -eq "zone" }).choices | where-object { $_.selected -eq $true }))
                    {
                        $row.selected = $false
                    }
                    ((($recoverygrab.fields | where-object {$_.name -eq "cloudcredentials"}).children | where-object {$_.name -eq "zone"}).choices | where-object {$_.name -eq $zone}) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                                        if (!($recoverygrab.formtype))
                    {
                        $recoverygrab.PSObject.Properties.Remove('@type')
                        $recoverygrab | Add-Member -MemberType NoteProperty -Name formtype -Value "existingmount"
                    }
                    $newjson = $recoverygrab | convertto-json -depth 10 -compress
                    $recoverygrab = Put-AGMAPIData -endpoint /backup/$imageid/mount -body $newjson 
                    $networklist = ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | sort-object displayName
                    $selectednetwork = (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).displayName
                    $subnetlist = ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "subnet" }).choices | sort-object displayName
                }
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
                $displayname  = ($machinetypelist| where-object { $_.selected -eq $true }).displayName
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
                    $machinetype = ($machinetypelist| where-object { $_.selected -eq $true }).name 
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
                write-host "Suggested service account (optional): $serviceaccountgrab" 
            }
           [string]$serviceaccount= Read-Host "Service Account" 
  
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
        Write-Host "Power on after creation?"
        Write-Host "1`: Power on after recovery (default)"
        Write-Host "2`: Power off after recovery"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq 2) {  $poweronvm = $false  } else {  $poweronvm = $true  } 

    
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
                $listmax = $networklist.displayName.count
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
                $selectednic0network = $networklist.displayName
            } else {
                $nic0network = $networklist.name[($netselection - 1)]
                $selectednic0network = $networklist.displayName[($netselection - 1)]
            }
        } else 
        {
            While ($true)  { if ($nic0network -eq "") { [string]$nic0network = Read-Host "NIC0 Network ID (mandatory)" } else { break } }
        }

        # if the network changes then the subnets will change
        if ($selectednic0network -ne $selectednetwork)
        {
            if ($recoverygrab.fields)
            {
                write-host "Fetching subnet list for nic0"
                # we need to send a modified packet backto learn the subnets in the users selected network
                foreach ($row in $recoverygrab.fields)
                {
                    $row.modified = $false
                }
                ($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).modified = $true
                ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).modified = $true
                foreach ($row in (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }))
                {
                    $row.selected = $false
                }
          
                (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.displayName -eq $selectednic0network }) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force

                $newjson = $recoverygrab | convertto-json -depth 10 -compress
                $recoverygrab = Put-AGMAPIData -endpoint /backup/$imageid/mount -body $newjson 
                write-host ""
                $subnetlist = ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "subnet" }).choices | sort-object displayName
                $selectednetwork = (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }).displayname
            }
        }
        if ($subnetlist.name)
        {
            write-host ""
            write-host "Subnet Selection for nic0"
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
        if (!($nic0subnet))
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
                    $listmax = $networklist.displayName.count
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
                    $selectednic1network = $networklist.displayName
                } else {
                    $nic1network = $networklist.name[($netselection - 1)]
                    $selectednic1network = $networklist.displayName[($netselection - 1)]
                }
            }
            else 
            {
                While ($true)  { if ($nic1network -eq "") { [string]$nic1network = Read-Host "NIC1 Network ID (mandatory)" } else { break } }
            }
            if ($selectednic1network -ne $selectednetwork)
            {
                if ($recoverygrab.fields)
                {
                    write-host "Fetching subnet list"
                    # we need to send a modified packet backto learn the subnets in the users selected network
                    ($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).modified = $true
                    ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).modified = $true
                    foreach ($row in (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.selected -eq $true }))
                    {
                        $row.selected = $false
                    }
                    (((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "vpc" }).choices | where-object { $_.displayName -eq $selectednic1network }) | Add-Member -MemberType NoteProperty -Name selected -Value $true -Force
                    $newjson = $recoverygrab | convertto-json -depth 10 -compress
                    $recoverygrab = Put-AGMAPIData -endpoint /backup/$imageid/mount -body $newjson 
                    write-host ""
                    $subnetlist = ((($recoverygrab.fields | where-object { $_.name -eq "networksettings" }).children).children | where-object { $_.name -eq "subnet" }).choices | sort-object displayName
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
                        $nic1subnet = $subnetlist.name
                    } else {
                        $nic1subnet = $subnetlist.name[($subselection - 1)]
                    }
                }
                if (!($nic1subnet))
                {
                    While ($true)  { if ($nic1subnet -eq "") { [string]$nic1subnet = Read-Host "NIC1 Subnet ID (mandatory)" } else { break } }
                }
            }
            else 
            {
                While ($true)  { if ($nic1subnet -eq "") { [string]$nic1subnet = Read-Host "NIC1 Subnet ID (mandatory)" } else { break } }
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
        $volumelist = ($recoverygrab.fields | where-object { $_.name -eq "volumes" })


        if ($volumelist)
        {
            if (!($disktype))
            {
                Write-Host ""
                Write-Host "Disk type Selection"
                Write-Host "1`: pd-balanced"
                Write-Host "2`: pd-extreme"
                Write-Host "3`: pd-ssd"
                Write-Host "4`: pd-standard"
                Write-Host ""
                Write-host ""
               
                While ($true) 
                {
                    Write-host ""
                    $listmax = 4
                    [int]$diskselection = Read-Host "Please select a disk type (1-$listmax)"
                    if ($diskselection -lt 1 -or $diskselection -gt $listmax)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                    } 
                    else
                    {
                        break
                    }
                }
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
                    $row | Add-Member -MemberType NoteProperty -Name selected -Value "true" -Force
                }
            }
            $diskjson = $volumelist | ConvertTo-json -depth 10 -compress
        }
        #Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline "New-AGMLibGCPInstance  -srcid $srcid -imageid $imageid -appid $appid -appname `"$appname`" -projectname `"$projectname`""
        Write-Host -nonewline " -zone `"$zone`" -instancename `"$instancename`" -machinetype `"$machinetype`"" 
        if ($serviceaccount) { Write-Host -nonewline " -serviceaccount `"$serviceaccount`"" }
        if ($networktags) { Write-Host -nonewline " -networktags `"$networktags`"" } 
        if ($poweronvm) { Write-Host -nonewline " -poweronvm $poweronvm" }
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
        Write-Host "2`: Write comma separated output.  This will mount the most recently created image for that application"
        Write-Host "3`: Exit without running the command"
        $userchoice = Read-Host "Please select from this list (1-3)"
        if ($userchoice -eq 3)
        {
            return
        }
        if ($userchoice -eq 2)
        {
            write-host "srcid,appid,appname,projectname,zone,instancename,machinetype,serviceaccount,networktags,poweronvm,labels,disktype,nic0network,nic0subnet,nic0externalip,nic0internalip,nic1network,nic1subnet,nic1externalip,nic1internalip"
            write-host -nonewline "$srcid,$appid,`"$appname`",`"$projectname`",`"$zone`",`"$instancename`",`"$machinetype`",`"$serviceaccount`",`"$networktags`""
            write-host -nonewline ",$poweronvm,$labels,$disktype,$nic0network,$nic0subnet,$nic0externalip,$nic0internalip,$nic1network,$nic1subnet,$nic1externalip,$nic1internalip"
            write-host ""
            return
        }

    }




    if ($disktype)
    {
        if (($disktype -ne "pd-balanced") -and ($disktype -ne "pd-extreme") -and ($disktype -ne "pd-ssd") -and ($disktype -ne "pd-standard"))
        {
            Get-AGMErrorMessage -messagetoprint "The Disk type requested using -disktype is not valid.   It needs to be one of pd-balanced, pd-extreme, pd-ssd or pd-standard"
            return
        }
    }


    # if recovery point specified without imagename or ID
    if ( (!($imagename)) -and (!($imageid)) -and ($appid) )
    {
        $imagecheck = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&apptype=GCPInstance" -sort id:desc -limit 1
        if ($imagecheck.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any images for appid $appid"
            return
        }
        $imageid = $imagecheck.id
        $imagename = $imagecheck.name
    }



    # learn about the image
    if (($imagename) -and (!($imageid)))
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
        }
    }
    if (($imageid) -and (!($imagename)))
    {
        $imagecheck = Get-AGMImage -id $imageid
        if (!($imagecheck))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imageid using:  Get-AGMImage -id $imageid"
            return
        }
        else 
        {
            $imagename = $imagegrab.name
        }
    }
    if ((!($imagename)) -and (!($imageid)))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify either -imageid or -imagename"
        return
    }


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
    # optionally handle nic1
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
    # optionally handle nic2
    if ((!($nic2network)) -and ($nic2subnet))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a network for nic2 for the new instance with -nic2network"
        return
    }
    if ((!($nic2subnet)) -and ($nic2network))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a subnet for nic2 for the new instance with -nic2subnet"
        return
    }
        # optionally handle nic3
    if ((!($nic3network)) -and ($nic3subnet))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a network for nic3 for the new instance with -nic3network"
        return
    }
    if ((!($nic3subnet)) -and ($nic3network))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a subnet for nic3 for the new instance with -nic3subnet"
        return
    }

    # disktype 
    #if ($disktype)
    #{
        $disktypegrab = Get-AGMAPIData -endpoint /backup/$imageid/mount -extrarequests "&formtype=newmount"
        if (!($disktypegrab.fields))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find data for image ID $imageid.  Please check this is a valid image ID with Get-AGMImage -id $imageid"
        return
        }
        if ($disktype)
        {
            foreach ($row in ($disktypegrab.fields | where-object { $_.name -eq "volumes" }).children.rows.disktype) {
                if ($row.selected -eq "True")
                {
                    $row.selected = ""
                }
            }
            foreach ($row in ($disktypegrab.fields | where-object { $_.name -eq "volumes" }).children.rows.disktype) {
                if ($row.name -eq $disktype)
                {
                    $row | Add-Member -MemberType NoteProperty -Name selected -Value "true" -force
                }
            }
        }
        $diskjson = $disktypegrab.fields | where-object { $_.name -eq "volumes" } | ConvertTo-json -depth 10 -compress
   # }

    if ($retainlabel -eq "true")
    {
        if ($disktypegrab)
        {
            $originallabels = ($disktypegrab.fields | where-object { $_.name -eq "tagsgroup" }).children.choices
        } else {
            $labelgrab = Get-AGMAPIData -endpoint /backup/$imageid/mount -extrarequests "&formtype=newmount"
            $originallabels = ($labelgrab.fields | where-object { $_.name -eq "tagsgroup" }).children.choices
        }
    }

    # cloud credentials
    $json = '{"cloudvmoptions":{"@type":"cloudVmMountRest","fields":[{"displayName":"","name":"cloudcredentials","helpId":1265,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"CLOUD CREDENTIALS NAME","name":"cloudcredential","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"credentialname","name":"' +$srcid +'","selected":true}],"_getchoices":"getCloudCredentials#cloudcredentiallist,image","_dependent":["project","zone","machinetype","networktag","vpc","subnet","privateips","externalip"],"_default":"1"},'
    #project name
    $json = $json + '{"displayName":"PROJECT NAME","name":"project","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"projectid","name":"' +$projectname +'","selected":true}],"_getchoices":"getAllProjects#handle,cloudcredential","_dependent":["zone","machinetype","networktag","vpc","subnet","privateips","externalip"],"_default":"projectid"},'
    # zone
    $json = $json + '{"displayName":"ZONE","name":"zone","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"zone","name":"' +$zone +'","selected":true}],"_getchoices":"getZones#handle,cloudcredential,region","_dependent":["machinetype","vpc","subnet","privateips","externalip"],"_default":"zone"}],"groupType":"layout"},'
    #instance name
    $json = $json + '{"displayName":"","name":"instancesettings","helpId":1265,"type":"group","description":"","required":true,"modified":true,"children":[{"displayName":"INSTANCE NAME","name":"instancename","helpId":1265,"type":"text","description":"","required":true,"currentValue":"' +$instancename +'","modified":true,"size":40,"_getDefault":"getDefaultInstanceName","invalid":"","_default":"instancename"},'
    # machine type
    $json = $json + '{"displayName":"MACHINE TYPE","name":"machinetype","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"machinetype","name":"' +$machinetype +'","selected":true}],"_getchoices":"getMachineTypes#handle,cloudcredential,region,project,zone","_dependent":["networksettings"],"_default":"machinetype"},'
    # service account
    if ($serviceaccount)
    {
        $json = $json + '{"displayName":"SERVICE ACCOUNT","name":"serviceaccount","helpId":1265,"type":"text","description":"","required":true,"currentValue":"' +$serviceaccount +'","modified":false,"size":40,"_getDefault":"getDefaultServiceAccount","_default":"gserviceaccount.com"},'
    } 
        # network tags   
    if (!($networktags))
    {
        $json = $json + '{"displayName":"NETWORK TAGS","name":"networktag","helpId":1265,"type":"multiselection","description":"","required":false,"modified":false,"minimum":0,"maximum":10,"choices":[{"displayName":"http-server","name":"http-server","selected":false},{"displayName":"https-server","name":"https-server","selected":false}],"_getchoices":"getNetworkTags#handle,cloudcredential,project","_default":"[]"}],"groupType":"layout"},'
    } else {
        $json = $json + '{"displayName":"NETWORK TAGS","name":"networktag","helpId":1265,"type":"multiselection","description":"","required":false,"modified":false,"minimum":0,"maximum":10,"choices":['
        $taggroup = ""
        foreach ($tag in $networktags.Split(","))
        {   
            $taggroup = $taggroup + '{"displayName":"' +$tag +'","name":"' +$tag +'","selected":true},'
        }
        $json = $json + $taggroup.TrimEnd(",")
        $json = $json + '],"_getchoices":"getNetworkTags#handle,cloudcredential,project","_default":"[]"}],"groupType":"layout"},'
    }
    # labels   
    if (!($labels))
    {
        if ($originallabels.key)
        {
            $json = $json + '{"displayName":"","name":"tagsgroup","helpId":1265,"type":"group","description":"","required":true,"modified":true,"children":[{"displayName":"Labels","name":"tag","helpId":1265,"type":"tagselection","description":"","modified":true,"minimum":1,"maximum":50,"choices":['
            $labelgroup = ""
            foreach ($label in $originallabels)
            {   
                if ($label.selected -eq "True")
                {
                    $labelgroup = $labelgroup + '{"selected":true,"key":"' +$label.key +'","value":"' +$label.value +'"},'
                }
            }
            $json = $json + $labelgroup.TrimEnd(",")
            $json = $json + '],"validation":""}],"groupType":"layout"},'

        } else {
            $json = $json + '{"displayName":"","name":"tagsgroup","helpId":1265,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"Labels","name":"tag","helpId":1265,"type":"tagselection","description":"","modified":true,"minimum":1,"maximum":50,"choices":[],"validation":""}],"groupType":"layout"},'
        }
    } else {
        $json = $json + '{"displayName":"","name":"tagsgroup","helpId":1265,"type":"group","description":"","required":true,"modified":true,"children":[{"displayName":"Labels","name":"tag","helpId":1265,"type":"tagselection","description":"","modified":true,"minimum":1,"maximum":50,"choices":['
        $labelgroup = ""
        foreach ($label in $labels.Split(","))
        {   
            $key = $label.Split(":") | Select-object -First 1
            $value = $label.Split(":") | Select-object -skip 1
            $labelgroup = $labelgroup + '{"selected":true,"key":"' +$key +'","value":"' +$value +'"},'
        }
        if ($originallabels.key)
        {
            foreach ($label in $originallabels)
            {   
                if ($label.selected -eq "True")
                {
                    # we need to validate that the user has not asked for the same key because if they have  we will get duplicate key and fail the job.    
                    #  if we retaining labels AND setting labels, then the user supplied key should win  If no user labels then no need to worry
                    if (!($labels))
                    {
                        $labelgroup = $labelgroup + '{"selected":true,"key":"' +$label.key +'","value":"' +$label.value +'"},'
                    }
                    else 
                    {
                        # set check value to false
                        $matchinglabel = $false
                        # go through each user label and if there is a matching original label, set check value to true
                        foreach ($userlabel in $labels.Split(","))
                        {   
                            $userkey = $userlabel.Split(":") | Select-object -First 1
                            if ( $userkey -eq $label.key )
                            {
                                $matchinglabel = $true
                            }
                        }
                        # if after checking all original labels to user labels we didnt get a match, then we can add the original label
                        if ($matchinglabel -eq $false)
                        {
                            $labelgroup = $labelgroup + '{"selected":true,"key":"' +$label.key +'","value":"' +$label.value +'"},'
                        }
                    }
                }
            }
        }
        $json = $json + $labelgroup.TrimEnd(",")
        $json = $json + '],"validation":""}],"groupType":"layout"},'
    }                                                                                                                    
    # network starter
    $json = $json + '{"displayName":"Network Interfaces","name":"networksettings","helpId":1265,"type":"networkinterfaces","description":"","required":true,"modified":false,"minimum":1,"maximum":2,"children":['
    ########## nic0   BEGIN ########
    $json = $json + '{"displayName":"nic0","name":"nic0","helpId":1265,"type":"nic","description":"","required":true,"modified":true,"children":['
    # network
    $json = $json + '{"displayName":"NETWORK","name":"vpc","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic0network +'","selected":true}],"_getchoices":"getVpcs#handle,cloudcredential,region,project,resourcegroup,zone","_dependent":["subnet","privateips"],"_default":"network","parentName":"nic0"},'
    # subnet
    $json = $json + '{"displayName":"SUBNET","name":"subnet","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic0subnet +'","selected":true}],"_getchoices":"getSubnets#handle,cloudcredential,region,vpc,project,zone","_dependent":["privateips"],"_default":"subnet","parentName":"nic0"},'
    # external IP    unless user asks for auto we default to none
    if ($nic0externalip -eq "auto")
    {
        $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0","selected":true},{"displayName":"None","name":"None"}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic0"},'
    } else {
        $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0"},{"displayName":"None","name":"None","selected":true}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic0"},'
    }                                                                                                                    
    # internal IP   The default is auto
    if ($nic0internalip)
    {
        $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic0","modified":false},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic0","modified":true},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":["' +$nic0internalip +'"],"disabled":true,"validation":"","parentName":"nic0"}],"parentName":"nic0"}]}'
    } else {
        $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":false,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic0"},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic0"},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":[],"disabled":true,"validation":"","parentName":"nic0"}],"parentName":"nic0"}]}'
        
    }
    ########## nic0   END ########
    ########## nic1   BEGIN ########
    if (($nic1network) -and ($nic1subnet)) 
    {
        $json = $json + ',{"displayName":"nic1","name":"nic1","helpId":1265,"type":"nic","description":"","required":true,"modified":true,"children":['
        # network
        $json = $json + '{"displayName":"NETWORK","name":"vpc","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic1network +'","selected":true}],"_getchoices":"getVpcs#handle,cloudcredential,region,project,resourcegroup,zone","_dependent":["subnet","privateips"],"_default":"network","parentName":"nic1"},'
        # subnet
        $json = $json + '{"displayName":"SUBNET","name":"subnet","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic1subnet +'","selected":true}],"_getchoices":"getSubnets#handle,cloudcredential,region,vpc,project,zone","_dependent":["privateips"],"_default":"subnet","parentName":"nic1"},'
        # external IP    unless user asks for auto we default to none
        if ($nic1externalip -eq "auto")
        {
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0","selected":true},{"displayName":"None","name":"None"}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic1"},'
        } else {
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0"},{"displayName":"None","name":"None","selected":true}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic1"},'
        }                                                                                                                    
        # internal IP   The default is auto
        if ($nic1internalip)
        {
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic1","modified":false},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic1","modified":true},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":["' +$nic1internalip +'"],"disabled":true,"validation":"","parentName":"nic1"}],"parentName":"nic1"}]}'
        } else {
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":false,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic1"},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic1"},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":[],"disabled":true,"validation":"","parentName":"nic1"}],"parentName":"nic1"}]}'
            
        }
    }
    ########## nic1   END ########
    ########## nic2   BEGIN ########
    if (($nic2network) -and ($nic2subnet)) 
    {
        $json = $json + ',{"displayName":"nic2","name":"nic2","helpId":1265,"type":"nic","description":"","required":true,"modified":true,"children":['
        # network
        $json = $json + '{"displayName":"NETWORK","name":"vpc","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic2network +'","selected":true}],"_getchoices":"getVpcs#handle,cloudcredential,region,project,resourcegroup,zone","_dependent":["subnet","privateips"],"_default":"network","parentName":"nic2"},'
        # subnet
        $json = $json + '{"displayName":"SUBNET","name":"subnet","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic2subnet +'","selected":true}],"_getchoices":"getSubnets#handle,cloudcredential,region,vpc,project,zone","_dependent":["privateips"],"_default":"subnet","parentName":"nic2"},'
        # external IP    unless user asks for auto we default to none
        if ($nic2externalip -eq "auto")
        {
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0","selected":true},{"displayName":"None","name":"None"}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic2"},'
        } else {
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0"},{"displayName":"None","name":"None","selected":true}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic2"},'
        }                                                                                                                    
        # internal IP   The default is auto
        if ($nic2internalip)
        {
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic2","modified":false},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic2","modified":true},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":["' +$nic2internalip +'"],"disabled":true,"validation":"","parentName":"nic2"}],"parentName":"nic2"}]}'
        } else {
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":false,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic2"},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic2"},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":[],"disabled":true,"validation":"","parentName":"nic2"}],"parentName":"nic2"}]}'
            
        }
    }
    ########## nic2   END ########
    ########## nic3   BEGIN ########
    if (($nic3network) -and ($nic3subnet)) 
    {
        $json = $json + ',{"displayName":"nic3","name":"nic3","helpId":1265,"type":"nic","description":"","required":true,"modified":true,"children":['
        # network
        $json = $json + '{"displayName":"NETWORK","name":"vpc","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic3network +'","selected":true}],"_getchoices":"getVpcs#handle,cloudcredential,region,project,resourcegroup,zone","_dependent":["subnet","privateips"],"_default":"network","parentName":"nic3"},'
        # subnet
        $json = $json + '{"displayName":"SUBNET","name":"subnet","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic3subnet +'","selected":true}],"_getchoices":"getSubnets#handle,cloudcredential,region,vpc,project,zone","_dependent":["privateips"],"_default":"subnet","parentName":"nic3"},'
        # external IP    unless user asks for auto we default to none
        if ($nic3externalip -eq "auto")
        {
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0","selected":true},{"displayName":"None","name":"None"}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic3"},'
        } else {
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0"},{"displayName":"None","name":"None","selected":true}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic3"},'
        }                                                                                                                    
        # internal IP   The default is auto
        if ($nic3internalip)
        {
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic3","modified":false},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic3","modified":true},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":["' +$nic3internalip +'"],"disabled":true,"validation":"","parentName":"nic3"}],"parentName":"nic3"}]}'
        } else {
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":false,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic3"},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic3"},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":[],"disabled":true,"validation":"","parentName":"nic3"}],"parentName":"nic3"}]}'
            
        }
    }
    ########## nic3   END ########

    

    # end networking  
    $json = $json + '],"groupType":"layout"},'
    


    # volumes
    if ($diskjson)
    {
        $json = $json + $diskjson +","
    } else {
        $json = $json + '{"displayName":"","name":"volumes","helpId":1265,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"Select Volumes to Mount","name":"volumeselection","helpId":1265,"type":"volumeselectiontable","description":"","required":false,"modified":false,"title":"Select Volumes to Mount","header":[{"displayName":"DEVICE NAME","name":"devicename","type":"text"},{"displayName":"SIZE","name":"size","type":"text"},{"displayName":"SOURCE MOUNT PATH","name":"sourcemountpath","type":"text"},{"displayName":"DEVICE INDEX","name":"deviceindex","type":"text"},{"displayName":"VOLUME ID","name":"volumeid","type":"text"},{"displayName":"DEVICE TYPE","name":"devicetype","type":"text"},{"displayName":"DISK TYPE","name":"disktype","type":"selection"}],"_getchoices":"getVolumeTypes#handle,cloudcredential,region,zone,project,machinetype"}],"groupType":"wizard"},'
    }
    # power on/off VM
    if ($poweronvm -eq "false")
    {
        $json = $json + '{"displayName":"","name":"checkboxgroup","helpId":1265,"type":"group","description":"","modified":false,"children":[{"displayName":"Power On","name":"poweronvm","helpId":1265,"type":"checkbox","description":"","modified":true,"checked":false}],"groupType":"layout"}],'
    } else {
        $json = $json + '{"displayName":"","name":"checkboxgroup","helpId":1265,"type":"group","description":"","modified":false,"children":[{"displayName":"Power On","name":"poweronvm","helpId":1265,"type":"checkbox","description":"","modified":true,"checked":true}],"groupType":"layout"}],'
    }
    # imagename
    $json = $json + '"version":1,"formtype":"newmount","image":"' +$imagename +'","cloudtype":"GCP"}}'

    $newgcp = Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json

    if ($newgcp.fields)
    {
        $invalid = (($newgcp.fields | Select-Object children).children | Select-Object invalid).invalid
        Get-AGMErrorMessage -messagetoprint $invalid
    }
    elseif ($newgcp.jobstatus) 
    {
        $newgcp.jobstatus = $newgcp.jobstatus.replace('Optional',' ')
        $newgcp | select-object jobstatus
    }
    else {
        $newgcp
    }
    
}