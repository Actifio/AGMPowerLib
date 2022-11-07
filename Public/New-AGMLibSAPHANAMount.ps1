
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

Function New-AGMLibSAPHANAMount ([string]$appid,[string]$targethostid,[string]$mountapplianceid,[string]$imagename,[string]$imageid,[string]$targethostname,[string]$appname,[string]$recoverypoint,[string]$label,[string]$dbsid,[string]$userstorekey,[string]$mountpointperimage,[string]$mountmode,[string]$mapdiskstoallesxhosts,[string]$sltid,[string]$slpid,[string]$jsonprint,[switch][alias("g")]$guided,[switch][alias("m")]$monitor,[switch][alias("w")]$wait) 
{
    <#
    .SYNOPSIS
    Mounts a SAP HANA Database Image

    .EXAMPLE
    New-AGMLibSAPHANAMount 
    You will be prompted through a guided menu

    .EXAMPLE
    New-AGMLibSAPHANAMount -appid 577110 -mountapplianceid 141767697828 -targethostid 483699 -dbsid "TGT" -userstorekey "ACTBACKUP" -mountpointperimage "/tgt"
    Mounts an SAP HANA Database with new SID to the desired mountpoint.

    .DESCRIPTION
    A function to mount SAP HANA Image

    * Image selection can be done three ways:

    1)  Run this command in guided mode to learn the available images and select one
    2)  Learn the imagename and specify that as part of the command with -imagename
    3)  Learn the Appid and Cluster ID for the appliance that will mount the image and then use -appid and -mountapplianceid 
    This will use the latest snapshot, StreamSnap or OnVault image on that appliance

    Note default values don't need to specified.  

    * label
    -label   Label for mount, recommended

    * mount host options:
    -targethostname   The target host specified by name.  Ideally use the next option
    -targethostid   The target host specified by id

    * mounted instance required settings
    -userstorekey xxxx   name of the HANA database user store key on the target server where a new SAP HANA Instance will get created.
    -mountpointperimage xxxx  path to the base directory where the configuration & database files for SAP HANA Instance on the target server are located.
    
    * Other options

    -recoverypoint  The point in time to roll forward to, in ISO8601 format like 2020-09-02 19:00:02

    * Reprotection:

    -sltid xxxx (short for Service Level Template ID) - if specified along with an slpid, will reprotect the mounted child app with the specified template and profile
    -slpid yyyy (short for Service Level Profile ID) - if specified along with an sltid, will reprotect the mounted child app with the specified template and profile    

    * VMware specific options
    -mountmode    use either nfs, vrdm or prdm
    -mapdiskstoallesxhosts   Either true to do this or false to not do this.  Default is false.  

    * Monitoring options:

    -wait     This will wait up to 2 minutes for the job to start, checking every 15 seconds to show you the job name
    -monitor  Same as -wait but will also run Get-AGMLibFollowJobStatus to monitor the job to completion 
    #>

    # its pointless procededing without a connection.
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
            $apptype = $appgrab.apptype
        }
    }

    if ( ($appid) -and (!($appname)) )
    {
        $appgrab = Get-AGMApplication -id $appid
        if(!($appgrab))
        {
            Get-AGMErrorMessage -messagetoprint "Cannot find appid $appid"
            return
        }
        else 
        {
            $appname = ($appgrab).appname
            $apptype = $appgrab.apptype
        }
    }

    # if recovery point specified without imagename or ID
    if ( ($recoverypoint) -and (!($imagename)) -and (!($imageid)) -and ($appid) )
    {
        $imagecheck = Get-AGMImage -filtervalue "appid=$appid&consistencydate<$recoverypoint&endpit>$recoverypoint" -sort id:desc -limit 1
        if (!($imagecheck))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find an image for appid $appid with a recovery point suitable for required ENDPit $recoverypoint "
            return
        }
    }

    # learn about the image if supplied a name
    if ( ($imagename) -and (!($imageid)) )
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
            $consistencydate = $imagegrab.consistencydate
            $endpit = $imagegrab.endpit
            $appname = $imagegrab.appname
            $appid = $imagegrab.application.id
            $apptype = $imagegrab.apptype      
            $restorableobjects = $imagegrab.restorableobjects
            $mountapplianceid = $imagegrab.cluster.clusterid   
        }
    }

    # learn about the image if supplied an ID
    if ( ($imageid) -and (!($imagename)) )
    {
        $imagegrab = Get-AGMImage -filtervalue id=$imageid
        if (!($imagegrab))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find Image ID $imageid using:  Get-AGMImage -filtervalue id=$imageid"
            return
        }
        else 
        {
            $consistencydate = $imagegrab.consistencydate
            $endpit = $imagegrab.endpit
            $appname = $imagegrab.appname
            $appid = $imagegrab.application.id
            $apptype = $imagegrab.apptype      
            $restorableobjects = $imagegrab.restorableobjects
            $mountapplianceid = $imagegrab.cluster.clusterid
        }
    }



    # if the user gave us nothing to start work, then enter guided mode
    if (( (!($appname)) -and (!($imagename)) -and (!($appid)) ) -or ($guided))
    {
        $guided = $true

        # first we need to work out which appliance we are mounting from 
        $appliancegrab = Get-AGMAppliance | select-object name,clusterid | sort-object name
        if ($appliancegrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any appliances to list."
            return
        }
        if ($appliancegrab.name.count -eq 1)
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
        write-host ""
        write-host "Running guided mode"
        write-host ""
        write-host "Application Select menu"
        write-host ""
        write-host "Select application status for SAP HANA apps with images"
        Write-host ""
        Write-Host "1`: Managed local apps (default)"
        Write-Host "2`: Unmanaged or imported apps"
        Write-Host "3`: Imported/mirrored apps (from other Appliances). If you cannot see imported apps, you may need to first run: Import-AGMLibOnVault"
        Write-Host ""
        [int]$userselectionapps = Read-Host "Please select from this list (1-3)"
        if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { $applist = Get-AGMApplication -filtervalue "managed=true&apptype=SAPHANA&sourcecluster=$mountapplianceid" | sort-object appname }
        if ($userselectionapps -eq 2) { $applist = Get-AGMApplication -filtervalue "managed=false&apptype=SAPHANA&sourcecluster=$mountapplianceid" | sort-object appname  }
        if ($userselectionapps -eq 3) { $applist = Get-AGMApplication -filtervalue "apptype=SAPHANA&sourcecluster!$mountapplianceid&clusterid=$mountapplianceid" | sort-object appname }

        if ($applist.count -eq 0)
        {
            if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { Get-AGMErrorMessage -messagetoprint "There are no managed SAP HANA apps to list" }
            if ($userselectionapps -eq 2)  { Get-AGMErrorMessage -messagetoprint "There are no unmanaged SAP HANA apps to list" }
            if ($userselectionapps -eq 3)  { Get-AGMErrorMessage -messagetoprint "There are no imported SAP HANA apps to list.  You may need to run Import-AGMLibOnVault first" }
            return
        }
        if ($applist.id.count -eq 0)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to find any $apptype apps"
            return
        }
        $i = 1
        foreach ($app in $applist)
        { 
            $applistname = $app.appname
            $appliance = $app.cluster.name 
            Write-Host -Object "$i`: $applistname ($appliance)"
            $i++
        }
        While ($true) 
        {
            Write-host ""
            $listmax = $applist.appname.count
            [int]$appselection = Read-Host "Please select an Application (1-$listmax)"
            if ($appselection -lt 1 -or $appselection -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
            } 
            else
            {
                break
            }
        }
        if ($applist.appname.count -eq 1)
        {
            $appname = $applist.appname
            $appid = $applist.id
        }
        else 
        {
            $appname = $applist.appname[($appselection - 1)]
            $appid = $applist.id[($appselection - 1)]
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
        else {
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

    if ( ($targethostid) -and (!($targethostname)) )
    {
        $hostgrab = Get-AGMHost -filtervalue id=$targethostid
        if (!($hostgrab))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $targethostid to a single host ID. Use Get-AGMLibHostID and try again specifying -targethostid"
            return
        }
        $targethostid = $targethostid
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
    
    # this if for guided menu
    if ($guided)
    {
       if (!($label))
       {
           Clear-Host
           [string]$label = Read-host "Label"
       }
        
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
 
                 $imagelist1 = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&targetuds=$mountapplianceid" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
                 
                 if ($imagelist1.id.count -eq 1)
                 {   
                    $imagegrab = Get-AGMImage -id $($imagelist1).id
                    $imagename = $imagegrab.backupname                
                    $consistencydate = $imagegrab.consistencydate
                    $endpit = $imagegrab.endpit
                    $appname = $imagegrab.appname
                    $appid = $imagegrab.application.id
                    $apptype = $imagegrab.apptype      
                    $restorableobjects = $imagegrab.restorableobjects | where-object {$_.systemdb -eq $false} 
                    $jobclass = $imagegrab.jobclass
                    $mountapplianceid = $imagegrab.cluster.clusterid
                    $mountappliancename = $imagegrab.cluster.name
                    write-host "Found one $jobclass image $imagename, consistency date $consistencydate on $mountappliancename"
                     Write-host ""
                 }
                 else 
                 {
                     Get-AGMErrorMessage -messagetoprint "Failed to fetch an image for appid $appid"   
                     return
                 }
             }
             if ($userselection -eq 2) 
             { 
                $imagelist1 = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&targetuds=$mountapplianceid"  | Sort-Object consistencydate,jobclass
                if ($imagelist1.id.count -eq 0)
                {
                    Get-AGMErrorMessage -messagetoprint "Failed to fetch any Images for appid $appid"
                    return
                }
                $imagelist = $imagelist1  | Sort-Object consistencydate
                if ($imagelist1.id.count -eq 1)
                {
                    $imagegrab = Get-AGMImage -id $($imagelist).id
                    $imagename = $imagegrab.backupname                
                    $consistencydate = $imagegrab.consistencydate
                    $endpit = $imagegrab.endpit
                    $appname = $imagegrab.appname
                    $appid = $imagegrab.application.id
                    $apptype = $imagegrab.apptype      
                    $restorableobjects = $imagegrab.restorableobjects | where-object {$_.systemdb -eq $false} 
                    $jobclass = $imagegrab.jobclass
                    $mountapplianceid = $imagegrab.cluster.clusterid
                    $mountappliancename = $imagegrab.cluster.name
                    write-host "Found one $jobclass image $imagename, consistency date $consistencydate on $mountappliancename"
                } 
                else
                {
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
                    # ask the user to choose
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
                    $endpit = $imagegrab.endpit
                    $appname = $imagegrab.appname
                    $appid = $imagegrab.application.id
                    $apptype = $imagegrab.apptype      
                    $restorableobjects = $imagegrab.restorableobjects | where-object {$_.systemdb -eq $false}
                    $mountapplianceid = $imagegrab.cluster.clusterid
                    $mountappliancename = $imagegrab.cluster.name 
                }
             }
        }
        
        # now we check the log date
        if ($endpit)
        {
            write-host ""
            $recoverypoint = Read-Host "Roll forward time (hitting enter means no roll-forward)`: $consistencydate to $endpit"
            if ($recoverypoint)
            {
                if ([datetime]$recoverypoint -lt $consistencydate)
                {
                    Get-AGMErrorMessage -messagetoprint "Specified recovery point $recoverypoint is earlier than image consistency date $consistencydate.  Specify an earlier image."
                    return
                }
                elseif ([datetime]$recoverypoint -gt $endpit)
                {
                    Get-AGMErrorMessage -messagetoprint "Specified recovery point $recoverypoint is later than available logs that go to $endpit"
                    return
                }
            }
        }
    
        if ( (!($targethostname)) -and (!($targethostid)))
        {
            $hostgrab = Get-AGMHost -filtervalue "sourcecluster=$mountapplianceid" | sort-object name
            if ($hostgrab -eq "" )
            {
                Get-AGMErrorMessage -messagetoprint "Cannot find any Linux hosts"
                return
            }
            Clear-Host
            Write-Host "Target host selection menu"
            $i = 1
            $printarray = @()
            foreach ($listedhost in $hostgrab)
            { 
                $printarray += [pscustomobject]@{
                    id = $i
                    hostname = $listedhost.name
                    hostid = $listedhost.id
                    vmtype = $listedhost.vmtype
                }
                $i++
            }
            #print the list
            $printarray | Format-table 
            write-host ""
            While ($true) 
            {
                $listmax = $hostgrab.name.count
                [int]$hostselection = Read-Host "Please select a host (1-$listmax)"
                if ($hostselection -lt 1 -or $hostselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            if ($hostgrab.name.count -eq 1)
            {
                $targethostname =  $hostgrab.name
                $targethostid = $hostgrab.id
            } else {
                $targethostname =  $hostgrab.name[($hostselection - 1)]
                $targethostid = $hostgrab.id[($hostselection - 1)]
            }
            $hostgrab = Get-AGMHost -id $targethostid
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
        
        # reprotection
        Clear-Host
        Write-Host "Reprotection"
        Write-Host "1`: Don't manage new application (default)"
        Write-Host "2`: Manage new application"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 2) 
        {   
            # slt selection
            Clear-Host
            Write-Host "SLT list"
            $objectgrab = Get-AGMSLT | sort-object name
            $i = 1
            foreach
            ($object in $objectgrab)
                { Write-Host -Object "$i`:  $($object.name) ($($object.id))"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $objectgrab.Length
                [int]$objectselection = Read-Host "Please select from this list (1-$listmax)"
                if ($objectselection -lt 1 -or $objectselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax]"
                } 
                else
                {
                    break
                }
            }
            $sltid =  $objectgrab[($objectselection - 1)].id

            #slp selection
            Clear-Host
            Write-Host "SLP list"
            $objectgrab = Get-AGMSLP -filtervalue clusterid=$mountapplianceid | sort-object name
            $i = 1
            foreach
            ($object in $objectgrab)
                { Write-Host -Object "$i`:  $($object.name) ($($object.id))"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $objectgrab.Length
                [int]$objectselection = Read-Host "Please select from this list (1-$listmax)"
                if ($objectselection -lt 1 -or $objectselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax]"
                } 
                else
                {
                    break
                }
            }
            $slpid =  $objectgrab[($objectselection - 1)].id
        }

       
        write-host ""
        
        While ($true) 
        {
            $dbsid = read-host "SAP HANA Target database SID"
            if ($dbsid -eq "")
            {
                Write-Host -Object "The Target database SID cannot be blank"
            } 
            else
            {
                break
            }
        }
        write-host ""
        While ($true) 
        {
            $userstorekey = read-host "SAP HANA Target user store key"
            if ($userstorekey -eq "")
            {
                Write-Host -Object "The Target user store key cannot be blank"
            } 
            else
            {
                break
            }
        }
        write-host ""
        While ($true) 
        {
            $mountpointperimage = read-host "SAP HANA Target filesystem mount point"
            if ($mountpointperimage -eq "")
            {
                Write-Host -Object "The Target Server filesystem mount point cannot be blank"
            } 
            else
            {
                break
            }
        }
        Write-host ""


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
        #volume info section
        #$logicalnamelist = $restorableobjects.volumeinfo | select-object logicalname,capacity,uniqueid | sort-object logicalname | Get-Unique -asstring
        Clear-Host  
        

        # we are done
       Clear-Host  
        Write-Host "Guided selection is complete. The values entered would result in the following command:"
        Write-Host ""
       
        Write-Host -nonewline "New-AGMLibSAPHANAMount -appid $appid -mountapplianceid $mountapplianceid -imagename $imagename -targethostid $targethostid -dbsid `"$dbsid`" -userstorekey `"$userstorekey`" -mountpointperimage `"$mountpointperimage`""
        if ($label)
        {
            Write-Host -nonewline " -label `"$label`""
        }
        if ($recoverypoint)
        {
            Write-Host -nonewline " -recoverypoint `"$recoverypoint`""
        }
        if ($mountmode)
        {
            Write-Host -nonewline " -mountmode $mountmode -mapdiskstoallesxhosts $mapdiskstoallesxhosts"
        }

        if ($sltid)
        {
            Write-Host -nonewline " -sltid $sltid -slpid $slpid"
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

    if ($targethostid -eq "")
    {
        Get-AGMErrorMessage -messagetoprint "Cannot proceed without a targethostid or targethostname"
        return
    }

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

    if ( ($sltid) -and (!($slpid)) )
    {
        Get-AGMErrorMessage -messagetoprint "An sltid $sltid was specified without an slpid with -slpid yyyy. Please specify both"
        return
    }
    if ( (!($sltid)) -and ($slpid) )
    {
        Get-AGMErrorMessage -messagetoprint "An slpid $slpid was specified without an sltid using -sltid xxxx. Please specify both"
        return
    }
    
    # learn about the image
    if (!($imagename)) 
    {
        Get-AGMErrorMessage -messagetoprint "No image was found to mount"
        return
    }

    # recovery point handling
    if ($recoverypoint)
    {
        $recoverytime = Convert-ToUnixDate $recoverypoint
    }
    
    if (!($label))
    {
        $label = ""
    }

    if (!($dbsid))
    {
        Get-AGMErrorMessage -messagetoprint "No database SID was specified"
        return
    }

    if (!($userstorekey))
    {
        Get-AGMErrorMessage -messagetoprint "No HANA user store key was specified"
        return
    }

    if (!($mountpointperimage))
    {
        Get-AGMErrorMessage -messagetoprint "No Target directory mount point was specified"
        return
    }

    if ($mountmode -eq "vrdm")
    {
        $physicalrdm = "0"
        $rdmmode = "independentvirtual"
    }
    if ($mountmode -eq "prdm")
    {
        $physicalrdm = "1"
        $rdmmode = "physical"
    }
    if ($mountmode -eq "nfs")
    {
        $physicalrdm = "2"
        $rdmmode = "nfs"
    }

    if ($mapdiskstoallesxhosts)
    {
        if (($mapdiskstoallesxhosts -ne "true") -and  ($mapdiskstoallesxhosts -ne "false"))
        {
            Get-AGMErrorMessage -messagetoprint "The value of Map to all ESXi hosts of $mapdiskstoallesxhosts is not valid. Must be true or false"
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

    $provisioningoptions = @()
    if ($consistencygroupname)
    {
        $provisioningoptions = $provisioningoptions +@{
                name = 'ConsistencyGroupName'
                value = $consistencygroupname
            }
    }
    $provisioningoptions = $provisioningoptions +@{
        name = 'dbsid'
        value = $dbsid
    }
    $provisioningoptions = $provisioningoptions +@{
        name = 'DBUSER'
        value = $userstorekey
    }
    
    if ($sltid)
    {
        $provisioningoptions= $provisioningoptions +@{
            name = 'reprotect'
            value = "true"
        }
        $provisioningoptions= $provisioningoptions +@{
            name = 'slt'
            value = $sltid
        }
        $provisioningoptions= $provisioningoptions +@{
            name = 'slp'
            value = $slpid
        }
    }
    $selectedobjects = @()
    $selectedobjects = $selectedobjects + [ordered]@{
        restorableobject = $appname
    }
    $body = [ordered]@{}
    if ($rdmmode) { $body = $body + [ordered]@{ rdmmode = $rdmmode; }}
    if ($physicalrdm) { $body = $body + [ordered]@{ physicalrdm = $physicalrdm; }}
    if ($label) { $body = $body + [ordered]@{ label = $label; }}
    $body = $body + [ordered]@{
        image = $imagename;
        host = @{id=$targethostid};
        hostclusterid = $mountapplianceid;
        appaware = "true";
        provisioningoptions = $provisioningoptions;
        selectedobjects = $selectedobjects
    }
    if ($restoreoptions)
    {
        $body = $body + @{ restoreoptions = $restoreoptions }
    }
    if ($recoverytime)
    {
        $body = $body + @{ recoverytime = [string]$recoverytime }
    }
    if ($restoreobjectmappings)
    {
        $body = $body + @{ restoreobjectmappings = $restoreobjectmappings }
    }

    $json = $body | ConvertTo-Json -depth 10

    if ($monitor)
    {
        $wait = $true
    }

    if ($jsonprint -eq "yes")
    {
        $compressedjson = $body | ConvertTo-Json -compress -depth 10
        Write-host "This is the final command:"
        Write-host ""
        Write-host "Post-AGMAPIData -endpoint /backup/$imageid/mount -body `'$compressedjson`'"
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
                write-host "Job not running yet, will wait 15 seconds and check again. Check $i of 8"
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