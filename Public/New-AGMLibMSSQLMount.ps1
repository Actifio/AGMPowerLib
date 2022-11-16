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


Function New-AGMLibMSSQLMount ([string]$appid,[string]$targethostid,[string]$mountapplianceid,[string]$imagename,[string]$imageid,[string]$targethostname,[string]$appname,[string]$sqlinstance,[string]$dbname,[string]$recoverypoint,[string]$recoverymodel,[string]$overwrite,[string]$label,[string]$consistencygroupname,[string]$dbnamelist,[string]$dbnameprefix,[string]$dbrenamelist,[string]$dbnamesuffix,[string]$recoverdb,[string]$userlogins,[string]$username,[string]$password,[string]$base64password,[string]$mountmode,[string]$mapdiskstoallesxhosts,[string]$mountpointperimage,[string]$sltid,[string]$slpid,[string]$perfoption,[switch][alias("d")]$discovery,[switch][alias("g")]$guided,[switch][alias("m")]$monitor,[switch][alias("w")]$wait) 
{
    <#
    .SYNOPSIS
    Mounts an MS SQL Image

    .EXAMPLE
    New-AGMLibMSSQLMount 
    You will be offered guided mode

    .EXAMPLE
    New-AGMLibMSSQLMount -appid 50322 -mountapplianceid 143112195179  -targethostid 51090 -sqlinstance "WIN-TARGET\SQLEXPRESS" -dbname "AdventureWorks2019" 
    Mounts the latest snapshot of a SQL Server database to specified host using specified appliance.  

    .EXAMPLE
    New-AGMLibMSSQLMount -appid 50318 -mountapplianceid 143112195179 -targethostid 51090 -sqlinstance "WIN-TARGET\SQLEXPRESS" -dbrenamelist "CRM,CRM1"
    Mounts the latest snapshot of a SQL Instance, mounting the CRM database but renaming it to CRM1 to specified host using specified appliance.

    .EXAMPLE
    New-AGMLibMSSQLMount -appid 50318 -mountapplianceid 143112195179 -targethostid 51090 -sqlinstance "WIN-TARGET\SQLEXPRESS" -dbrenamelist "AdventureWorks2019,test1;CRM,test2" -consistencygroupname "cg1mount"
    Mounts the latest snapshot of a SQL Instance, mounting two databases but changing the target DB names.   Because two DBs are mounted a consistencygroup name is also needed.
    
    .EXAMPLE
    New-AGMLibMSSQLMount -appid 50318 -mountapplianceid 143112195179 -targethostid 51090 -sqlinstance "WIN-TARGET\SQLEXPRESS" -dbnamelist "AdventureWorks2019,CRM" -consistencygroupname "cg1mount"
    Mounts the latest snapshot of a SQL Instance, mounting two databases but not changing the target DB names (dbnamelist, not dbrenamelist).   Because two DBs are mounted a consistencygroup name is also needed. 

    .DESCRIPTION
    A function to mount MS SQL Image

    * Image selection can be done three ways:

    1)  Run this command in guided mode to learn the available images and select one
    2)  Learn the imagename and specify that as part of the command with -imagename
    3)  Learn the Appid and Cluster ID for the appliance that will mount the image and then use -appid and -mountapplianceid 
    This will use the latest snapshot, StreamSnap or OnVault image on that appliance

    Note default values don't need to specified.  So for instance these are both unnecessary:   -recoverdb true -userlogins false

    * label
    -label   Label for mount, recommended

    * mount host options:
    -sqlinstance  The SQL instance on the host we are mounting into
    -targethostname   The target host specified by name.  Ideally use the next option
    -targethostid   The target host specified by id

    *  mounted app names
    -dbname  If mounting only one DB use this option.  This is the name of the new database that will be created.
    -dbnamelist  If mounting more than one DB, use this comma separated.  It is better to use -dbrenamelist 
    -dbrenamelist   Semicolon separated list of comma separated source db and target db.  So if we have two source DBs, prod1 and prod2 and we mount them as dev1 and dev2 then:   prod1,dev1;prod2,dev2
    -consistencygroupname  If mounting more than one DB then you will need to specify a CG name.  This is used on the Appliance side to group the new apps, the mounted host wont see this name
    -dbnamesuffix option to add a suffix.  Use this with -dbnamelist
    -dbnameprefix option to add a prefix.  Use this with -dbnamelist
    
    * Other options

    -mountpointperimage
    -recoverypoint  The point in time to roll forward to, in ISO8601 format like 2020-09-02 19:00:02.   Or the word 'latest' to apply all available logs
    -recoverymodel   use either:   "Same as source" (default) or "Simple" or "Full" or "Bulk logged"
    -overwrite    use either:   "no" (default)  "stale" or "yes"
    -recoverdb    true=Recover database after restore (default) false=Don't recovery database after restore
    -userlogins   false=Don't recover user logins(default)    true=Recover User Logins
    -discovery     This is a switch, so if specified will run application discovery on the selected targethostid
    -mountapplianceid XXXX    Runs the mount on the specified appliance
    -perfoption    Used only with OnVault images, you can specify either:  StorageOptimized, Balanced, PerformanceOptimized or MaximumPerformance

    * Reprotection:

    -sltid xxxx (short for Service Level Template ID) - if specified along with an slpid, will reprotect the mounted child app with the specified template and profile
    -slpid yyyy (short for Service Level Profile ID) - if specified along with an sltid, will reprotect the mounted child app with the specified template and profile

    * Username and password:
    
    -username  This is the username (optional)
    -password   This is the password in plain text (not a good idea)
    -base64password   This is the password in base 64 encoding
    To create this:
    $password = 'passw0rd'
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($password)
    $base64password =[Convert]::ToBase64String($Bytes)

    * VMware specific options
    -mountmode    use either   nfs, vrdm or prdm
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
        $appgrab = Get-AGMApplication -filtervalue id=$appid
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
        if ($recoverypoint -ne "latest")
        {
            $imagecheck = Get-AGMImage -filtervalue "appid=$appid&consistencydate<$recoverypoint&endpit>$recoverypoint" -sort id:desc -limit 1
            if (!($imagecheck))
            {
                Get-AGMErrorMessage -messagetoprint "Failed to find an image for appid $appid with a recovery point suitable for required ENDPit $recoverypoint "
                return
            }
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
            $imagejobclass = $imagegrab.jobclass    
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
            $imagejobclass = $imagegrab.jobclass   
        }
    }
    # if user asked for latest recovery point, and there are logs,  we roll forward all the way
    if (($endpit) -and ($recoverypoint -eq "latest"))
    {
        $recoverypoint = $endpit
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
                 Write-Host -Object "$i`: $($appliance.name) ($($appliance.clusterid))"
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
        Clear-Host
        Write-Host "What App Type do you want to work with:"
        Write-Host "1`: SQL Server (default)"
        Write-Host "2`: Sql Instance"
        Write-Host "3`: SQL Server Availability Group"
        Write-Host "4`: Consistency Group"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $apptype = "SqlServerWriter"  }
        if ($userselection -eq 2) {  $apptype = "SqlInstance"  }
        if ($userselection -eq 3) {  $apptype = "SQLServerAvailabilityGroup"  }
        if ($userselection -eq 4) {  $apptype = "ConsistGrp"  }
        write-host ""
        write-host "Select application status for $apptype apps"
        Write-host ""
        Write-Host "1`: Managed local apps (default)"
        Write-Host "2`: Unmanaged or imported apps"
        Write-Host "3`: Imported/mirrored apps (from other Appliances). If you cannot see imported apps, you may need to first run: Import-AGMLibOnVault"
        Write-Host ""
        [int]$userselectionapps = Read-Host "Please select from this list (1-3)"
        if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { $applist = Get-AGMApplication -filtervalue "managed=true&apptype=$apptype&sourcecluster=$mountapplianceid" | sort-object appname }
        if ($userselectionapps -eq 2) { $applist = Get-AGMApplication -filtervalue "managed=false&apptype=$apptype&sourcecluster=$mountapplianceid" | sort-object appname  }
        if ($userselectionapps -eq 3) { $applist = Get-AGMApplication -filtervalue "apptype=$apptype&sourcecluster!$mountapplianceid&clusterid=$mountapplianceid" | sort-object appname }
        if ($applist.id.count -eq 0)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to find any $apptype apps"
            return
        }
        if ($userselection -eq 1)
        {
            $i = 1
            Clear-Host
            Write-host "Application selection menu"
            Write-host ""
            foreach ($app in $applist)
            { 
                $applistname = $app.appname
                $appliance = $app.cluster.name 
                $pathname = $app.pathname
                Write-Host -Object "$i`: $pathname`\$applistname ($appliance)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $applist.appname.count
                [int]$appselection = Read-Host "Please select an App (1-$listmax)"
                if ($appselection -lt 1 -or $appselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            if ($applist.id.count -eq 1)
            {
                $appname = $applist.appname
                $appid = $applist.id
                $slaid = $applist.sla.id
            }
            else 
            {
                $appname = $applist.appname[($appselection - 1)]
                $appid = $applist.id[($appselection - 1)]
                $slaid = $applist.sla.id[($appselection - 1)]
            }
            $slamatchgrab = Get-AGMSLA -id $slaid
            $slaappname = $slamatchgrab.application.appname
            $slaapptype = $slamatchgrab.application.friendlytype
            $slaappid = $slamatchgrab.application.id

            if ($slaappid -ne $appid)
            {
                write-host ""
                Write-Host "The application you have selected is managed as part of a $slaapptype called $slaappname  Would you like to go to the Access page for the $slaapptype instead?"
                Write-host ""
                Write-Host "1`: Yes (default)"
                Write-Host "2`: No"
                Write-Host ""
                [int]$groupswitch = Read-Host "Please select from this list (1-2)"
                if ($groupswitch -ne 2)
                {
                    $appname = $slaappname
                    $appid = $slaappid
                }
            }
        }
        else 
        {    
            $i = 1
            Clear-Host
            Write-host "Group selection menu"
            Write-host ""
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
                [int]$appselection = Read-Host "Please select an App (1-$listmax)"
                if ($appselection -lt 1 -or $appselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            if ($applist.id.count -eq 1)
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
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $targethostid to a single host ID.  Use Get-AGMLibHostID and try again specifying -targethostid"
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
            Write-Host "Image selection"
            Write-Host "1`: Use the most recent backup for lowest RPO (default)"
            Write-Host "2`: Select a backup"
            Write-Host ""
            While ($true) 
            {
                [int]$rposelection = Read-Host "Please select from this list (1-2)"
                if ($rposelection -eq "") { $rposelection = 1 }
                if ($rposelection -lt 1 -or $rposelection -gt 2)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-2]"
                } 
                else
                {
                    break
                }
            }
            if ($rposelection -eq 1)
            {
                $imagegrab = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&targetuds=$mountapplianceid" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
                if ($imagegrab.id.count -eq 0)
                {
                    Get-AGMErrorMessage -messagetoprint "Failed to fetch any Images for appid $appid on target appliance $mountapplianceid"
                    return
                }
               else
                {
                    $imagegrab = Get-AGMImage -id $($imagegrab).id
                    $imagename = $imagegrab.backupname                
                    $consistencydate = $imagegrab.consistencydate
                    $endpit = $imagegrab.endpit
                    $appname = $imagegrab.appname
                    $appid = $imagegrab.application.id
                    $apptype = $imagegrab.apptype      
                    $restorableobjects = $imagegrab.restorableobjects
                    $imagejobclass = $imagegrab.jobclass
                    $mountapplianceid = $imagegrab.cluster.clusterid
                    $mountappliancename = $imagegrab.cluster.name
                    #write-host "Found one $imagejobclass image $imagename, consistency date $consistencydate on $mountappliancename"
                } 
            }   
            
            if ($rposelection -eq 2)
                {
                $imagelist1 = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&targetuds=$mountapplianceid"  | select-object -Property backupname,consistencydate,endpit,id,jobclass,cluster | Sort-Object consistencydate,jobclass
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
                    $restorableobjects = $imagegrab.restorableobjects
                    $imagejobclass = $imagegrab.jobclass
                    $mountapplianceid = $imagegrab.cluster.clusterid
                    $mountappliancename = $imagegrab.cluster.name
                    write-host "Found one $imagejobclass image $imagename, consistency date $consistencydate on $mountappliancename"
                } 
                else
                {
                    Clear-Host
                    Write-Host "Image list.  Choose the best jobclass and consistency date on the mount appliance"
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
                    $restorableobjects = $imagegrab.restorableobjects
                    $mountapplianceid = $imagegrab.cluster.clusterid
                    $mountappliancename = $imagegrab.cluster.name
                    $imagejobclass = $imagegrab.jobclass   
                }
            }
        }
        if ($imagejobclass -eq "OnVault")
        {
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
        
        # now we check the log date
        if ($endpit)
        {
            write-host ""
            Write-Host "Log handling"
            Write-Host "1`: Mount without applying logs (default)"
            Write-Host "2`: Enter a recovery point"
            Write-Host "3`: Apply all available logs (lowest RPO)"
            Write-Host ""
            While ($true) 
            {
                [int]$logselection = Read-Host "Please select from this list (1-3)"
                if ($logselection -eq "") { $logselection = 1 }
                if ($logselection -lt 1 -or $logselection -gt 3)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-3]"
                } 
                else
                {
                    break
                }
            }
            if ($logselection -eq 2)
            {
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
            if ($logselection -eq 3)
            {
                $recoverypoint="latest"
            }
        }
    
        if ( (!($targethostname)) -and (!($targethostid)))
        {
            $hostgrab1 = Get-AGMApplication -filtervalue "apptype=SqlInstance&sourcecluster=$mountapplianceid"
            $hostgrab = ($hostgrab1).host | sort-object -unique id | select-object id,name 
            Clear-Host
            Write-Host "Target host selection menu (use option 0 to run discovery)"
            $i = 1
            Write-Host -Object "0`: I need to run app discovery on a host"
            foreach ($name in $hostgrab.name)
            { 
                Write-Host -Object "$i`: $name"
                $i++
            }
            While ($true) 
            {
                $listmax = $hostgrab.name.count
                [int]$hostselection = Read-Host "Please select a host (0-$listmax)"
                if ($hostselection -lt 0 -or $hostselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            if ($hostselection -eq 0)
            {
                
                write-host ""
                write-host "Host discovery menu"
                $hostgrab = Get-AGMHost -filtervalue "sourcecluster=$mountapplianceid" | sort-object name 
                if ($hostgrab -eq "" )
                {
                    Get-AGMErrorMessage -messagetoprint "Cannot find any hosts"
                    return
                }
                Clear-Host
                Write-Host "Discovery host selection menu"
                $i = 1
                foreach ($potentialhost in $hostgrab)
                { 
                    Write-Host -Object "$i`:  $($potentialhost.name) ($($potentialhost.ipaddress))"
                    $i++
                }
                While ($true) 
                {
                    $listmax = $hostgrab.name.count
                    [int]$dischostselection = Read-Host "Please select a host (1-$listmax)"
                    if ($dischostselection -lt 1 -or $dischostselection -gt $listmax)
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
                    $targethostname = $hostgrab.name
                    $targethostid = $hostgrab.id
                }
                else
                {
                    $targethostname = $hostgrab.name[($dischostselection - 1)]
                    $targethostid = $hostgrab.id[($dischostselection - 1)]
                }
                write-host ""
                write-host "Running discovery on selected host ID $targethostid on Appliance ID $mountapplianceid"
                New-AGMAppDiscovery -hostid $targethostid -applianceid $mountapplianceid
                write-host "Sleeping for 30 seconds"
                Start-Sleep -s 30
            }
            else
            {
                if ($hostgrab.name.count -eq 1)
                {
                    $targethostname =  $hostgrab.name
                    $targethostid = $hostgrab.id
                }
                else
                {
                    $targethostname =  $hostgrab.name[($hostselection - 1)]
                    $targethostid = $hostgrab.id[($hostselection - 1)]
                }
            }

        }

        # now we determine the instance to mount to
        $instancelist = Get-AGMApplication -filtervalue "hostid=$targethostid&apptype=SqlInstance"
        if ( (!($instancelist)) -or ($instancelist.count -eq 0) )
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any SQL Instances on $targethostname.  Specify a target host with discovered SQL Instances"
            return
        }
        if ($instancelist.id.count -eq 1)
        {
            $sqlinstance = ($instancelist).appname
            write-host ""
            Write-Host "SQL instance $sqlinstance will be used"
            write-host ""
        } 
        else
        {
            write-host ""
            Write-Host "SQL instance list"
            $i = 1
            foreach
            ($instance in $instancelist.appname)
                { Write-Host -Object "$i`:  $instance"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $instancelist.id.count
                [int]$instanceselection = Read-Host "Please select an instance (1-$listmax)"
                if ($instanceselection -lt 1 -or $instanceselection -gt $instancelist.Length)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($instancelist.Length)]"
                } 
                else
                {
                    break
                }
            }
            $sqlinstance =  $instancelist[($instanceselection - 1)].appname
            Clear-Host
        }
        # reprotection
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


        # now we look for restoreable objects
        if ($apptype -ne "SqlServerWriter")
        {
            if (!($restorableobjects))
            {
                Write-Host -Object "The image did not have any restoreable objects"
                return
            }
            foreach ($db in $restorableobjects.name)
            { 
                $mountedname =
                [string]$mountedname = Read-Host "Target name for $db (press enter to skip)"
                if ($mountedname)
                {
                    if ($dbrenamelist)
                    {
                        $dbrenamelist = $dbrenamelist + ";$db,$mountedname"
                    } else {
                        $dbrenamelist = "$db,$mountedname"
                    }
                }
            }
        }
         # if the dbnamelist has only one DB in it,  we need to get a DB name, otherwise we need to enter CG processing.
        if ($apptype -eq "SqlServerWriter")
        {
            if (!($dbname))
            {
                Clear-Host
                While ($true) 
                {
                    $dbname = Read-Host "SQL Server Database Name"
                    if ($dbname -eq "")
                    {
                        Write-Host -Object "The DB Name cannot be blank"
                    } 
                    else
                    {
                        break
                    }
                }
            }
        }
        if ($dbrenamelist.Split(";").count -gt 1)
        {
            # consistency group is mandatory
            Clear-Host
            While ($true) 
            {
                $consistencygroupname = Read-Host "Name of Consistency Group"
                if ($consistencygroupname -eq "")
                {
                    Write-Host -Object "The CG Name cannot be blank"
                } 
                else
                {
                    break
                }
            }
           
        }
        # recover DB
        Clear-Host
        Write-Host "Recover database"
        Write-Host "1`: Recover database after restore(default)"
        Write-Host "2`: Don't recovery database after restore"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $recoverdb = "true"  }
        if ($userselection -eq 2) {  $recoverdb = "false"  }
        # recover User Logins
        Clear-Host
        Write-Host "User Login recovery"
        Write-Host "1`: Don't recover user logins(default)"
        Write-Host "2`: Recover User Logins"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $userlogins = "false"  }
        if ($userselection -eq 2) {  $userlogins = "true"  }

        Write-host ""
        $username = read-host "Username (optional)"
        if ($username)
        {
            $passwordenc = Read-Host -AsSecureString "Password"
            if ($passwordenc.length -ne 0)
            {
                $UnsecurePassword = ConvertFrom-SecureString -SecureString $passwordenc -AsPlainText
                $base64password = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UnsecurePassword))
            }
        }

        # recovery model
        Clear-Host
        Write-Host "Recovery model"
        Write-Host "1`: Same as source (default)"
        Write-Host "2`: Simple Logging mode"
        Write-Host "3`: Full Logging mode"
        Write-Host "4`: Bulk Logged mode"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-4)"
        if ($userselection -eq "") { $recoverymodel = "Same as source" }
        if ($userselection -eq 1) {  $recoverymodel = "Same as source" }
        if ($userselection -eq 2) {  $recoverymodel = "Simple"  }
        if ($userselection -eq 3) {  $recoverymodel = "Full"  }
        if ($userselection -eq 4) {  $recoverymodel = "Bulk logged"  }
        #overwrite existing database
        Clear-Host
        Write-Host "Overwrite existing database"
        Write-Host "1`: No (default)"
        Write-Host "2`: Only if its stale"
        Write-Host "3`: Yes"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-3)"
        if ($userselection -eq "") { $overwrite = "no" }
        if ($userselection -eq 1) {  $overwrite = "no"  }
        if ($userselection -eq 2) {  $overwrite = "stale"  }
        if ($userselection -eq 3) {  $overwrite = "yes"  }

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
        $logicalnamelist = $restorableobjects.volumeinfo | select-object logicalname,capacity,uniqueid | sort-object logicalname | Get-Unique -asstring
        Clear-Host  
        

        if ($logicalnamelist.count -eq 1)
        {
            Write-Host "This image has only one drive. You can change mount point used or allow the Connector to determine this"
            Write-Host ""
            $mountpointperimage = ""
            $mountpointperimage = Read-Host "Mount Location (optional)"
            
        }
        if ($logicalnamelist.count -gt 1)
        {
            Write-Host "This image has more than one drive. You can enter a Mount Location, or press enter to set mount points per drive. "
            Write-Host ""
            $mountpointperimage = ""
            $mountpointperimage = Read-Host "Mount Location (optional)"
            if ($mountpointperimage -eq "")
            {
                Clear-Host
                $mountpointspervol = ""
                $mountpointspervol1 = ""
                Write-Host "Set mount Locations per drive, or press enter to allow the Connector to determine this."
                foreach ($logicalname in $logicalnamelist)
                { 
                    $capacity = [math]::Round($logicalname.capacity / 1073741824,1)
                    $diskname = $logicalname.logicalname
                    $uniqueid = $logicalname.uniqueid
                    $mountpointgrab = ""
                    [string]$mountpointgrab = Read-Host "$diskname   $capacity GiB"
                    if ($mountpointgrab -ne "")
                    {
                        $mountpointspervol1 = $mountpointspervol1 + "," + "$uniqueid" + "=" + "$mountpointgrab"
                    }
                    if ($mountpointspervol1 -ne "")
                    {
                        $mountpointspervol = $mountpointspervol1.substring(1)
                    }
                }
            }
        }

        # we are done
       Clear-Host  
        Write-Host "Guided selection is complete.  The values entered would result in the following command:"
        Write-Host ""
      
        Write-Host -nonewline "New-AGMLibMSSQLMount -appid $appid -mountapplianceid $mountapplianceid  -targethostid $targethostid -sqlinstance `"$sqlinstance`""
        if ($rposelection -eq 2 )
        {
            Write-Host -nonewline "-imagename `"$imagename`""
        }
        if ($recoverypoint)
        {
            Write-Host -nonewline " -recoverypoint `"$recoverypoint`""
        } 
        if ($dbname)
        {
            Write-Host -nonewline " -dbname `"$dbname`""
        }
        if ($dbnamelist)
        {
            Write-Host -nonewline " -dbnamelist `"$dbnamelist`""
        } 
        if ($dbrenamelist)
        {
            Write-Host -nonewline " -dbrenamelist `"$dbrenamelist`""
        } 
        if ($consistencygroupname)
        {
            Write-Host -nonewline " -consistencygroupname `"$consistencygroupname`""
        } 
        if ($recoverymodel)
        {
            Write-Host -nonewline " -recoverymodel `"$recoverymodel`""
        }
        if ($overwrite)
        {
            Write-Host -nonewline " -overwrite `"$overwrite`""
        }
        if ($recoverdb)
        {
            Write-Host -nonewline " -recoverdb `"$recoverdb`""
        }
        if ($userlogins)
        {
            Write-Host -nonewline " -userlogins `"$userlogins`""
        }
        if ($label)
        {
            Write-Host -nonewline " -label `"$label`""
        }
        if ($username)
        {
            Write-Host -nonewline " -username $username -base64password `"$base64password`""
        }
        if ($mountmode)
        {
            Write-Host -nonewline " -mountmode $mountmode -mapdiskstoallesxhosts $mapdiskstoallesxhosts"
        }
        if ($mountpointperimage)
        {
            Write-Host -nonewline " -mountpointperimage `"$mountpointperimage`""
        }
        if ($mountpointspervol)
        {
            Write-Host -nonewline " -mountpointspervol `"$mountpointspervol`""
        }
        if ($sltid)
        {
            Write-Host -nonewline " -sltid $sltid -slpid $slpid"
        }
        if ($dbnameprefix)
        {
            Write-Host -nonewline " -dbnameprefix `"$dbnameprefix`""
        }
        if ($dbnamesuffix)
        {
            Write-Host -nonewline " -dbnamesuffix `"$dbnamesuffix`""
        }     
        if ($perfoption)
        {
            Write-Host -nonewline " -perfoption `"$perfoption`""
        }  
        Write-Host ""
        Write-Host "1`: Run the command now (default)"
        Write-Host "2`: Print CSV output"
        Write-Host "3`: Exit without running the command"
        $userchoice = Read-Host "Please select from this list (1-3)"
        if ($userchoice -eq 2)
        {
            write-host ""
            Write-Host "Are you planning to migrate the database after mount"
            Write-Host "1`: No (default)"
            Write-Host "2`: Yes"
            Write-Host ""
            $userselection = ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $migrate = "" }
            if ($userselection -eq 1) {  $migrate = ""  }
            if ($userselection -eq 2) {  $migrate = "yes"  }
            if ($migrate -eq "yes")
            {
                Write-Host ""
                While ($true) 
                {
                    [int]$frequency = Read-Host "Frequency between 1-24 hours (hit enter for default of 24)"
                    if ($frequency -eq "") { $frequency = 24 }
                    if ($frequency -lt 1 -or $frequency -gt 24)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-24] or press enter for default of 24"
                    } 
                    else
                    {
                        break
                    }
                }
                Write-Host ""
                Write-Host "Rename files to match new database name"
                Write-Host "1`: Yes (default)"
                Write-Host "2`: No"
                Write-Host ""
                $userselection = ""
                [int]$userselection = Read-Host "Please select from this list (1-2)"
                if ($userselection -eq "") { $dontrenamedatabasefiles = "" }
                if ($userselection -eq 1) {  $dontrenamedatabasefiles = ""  }
                if ($userselection -eq 2) {  $dontrenamedatabasefiles = "yes"  }
                Write-Host ""
                While ($true) 
                {
                    [int]$copythreadcount = Read-Host "Copy thread count between 1-20 (hit enter for default of 4)"
                    if ($copythreadcount -eq "") { $copythreadcount = 4 }
                    if ($copythreadcount -lt 1 -or $copythreadcount -gt 20)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-20] or press enter for default of 4"
                    } 
                    else
                    {
                        break
                    }
                }
                Write-Host ""
                Write-Host "Select File Destination For Migrated Files"
                Write-Host "1`: Copy files to the same drive/path as they were on the source server (default)"
                Write-Host "2`: Choose new file locations at the volume level"
                Write-Host "3`: Choose new locations at the file level."
                Write-Host ""
                $userselection = ""
                [int]$userselection = Read-Host "Please select from this list (1-3)"
                if ($userselection -eq 2) 
                {  
                    $volumes = "yes"  
                    write-host "Format for volume restore list is to comma separate each source,target drive and semicolon separate each drive pair, example:  D:\,K:\;E:\,M:\"
                    write-host "This migrates D: to K:   and also migrates E: to M:"
                    write-host ""
                    $restorelist = Read-Host "Please enter a list of source/target drives"
                }
                if ($userselection -eq 3) 
                {  
                    $files = "yes"  
                    write-host "Format for File restore list is to comma separate each file,sourcedir,targetdir  and semicolon separate each trio, example: filename1,source1,target1;filename2,source2,target2"
                    write-host "This migrates filename1 currently in source1 folder to target1 folder and also migrate filename2 currently in source2 folder to target2 folder"
                    write-host ""
                    $restorelist = Read-Host "Please enter a list of file,sourcedir,targetdirs"
                }
            }
            if ($rposelection -eq 1)
            {
                $printimagename = ""
                $printimageid = ""
            }
            else {
                $printimagename = $imagename
                $printimageid = $imageid
            }

            write-host "appid,appname,imagename,imageid,mountapplianceid,targethostid,targethostname,sqlinstance,recoverypoint,recoverymodel,overwrite,label,dbname,consistencygroupname,dbnamelist,dbrenamelist,dbnameprefix,dbnamesuffix,recoverdb,userlogins,username,password,base64password,mountmode,mapdiskstoallesxhosts,mountpointperimage,sltid,slpid,discovery,perfoption,migrate,copythreadcount,frequency,dontrenamedatabasefiles,volumes,files,restorelist"
            write-host -nonewline "`"$appid`",`"$appname`",`"$printimagename`",`"$printimageid`",`"$mountapplianceid`",`"$targethostid`",`"$targethostname`",`"$sqlinstance`",`"$recoverypoint`",`"$recoverymodel`",`"$overwrite`",`"$label`",`"$dbname`",`"$consistencygroupname`",`"$dbnamelist`",`"$dbrenamelist`",`"$dbnameprefix`",`"$dbnamesuffix`",`"$recoverdb`",`"$userlogins`",`"$username`",`"$password`",`"$base64password`",`"$mountmode`",`"$mapdiskstoallesxhosts`",`"$mountpointperimage`",`"$sltid`",`"$slpid`","
            if ($discovery) {  write-host -nonewline  `"$discovery`" } else { write-host -nonewline  "," }
            write-host -nonewline "`"$perfoption`",`"$migrate`",$copythreadcount,$frequency,`"$dontrenamedatabasefiles`",`"$volumes`",`"$files`",`"$restorelist`""
            write-host ""
            return   
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
        if ($imagegrab.id.count -eq 1)
        {   
            $imageid = $imagegrab.id
            $imagename = $imagegrab.backupname
            $imagejobclass = $imagegrab.jobclass
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot, StreamSnap or OnVault Image for appid $appid on appliance with clusterID $mountapplianceid"
            return
        }
    }

    if ( ($sltid) -and (!($slpid)) )
    {
        Get-AGMErrorMessage -messagetoprint "An sltid $sltid was specified without an slpid with -slpid yyyy.   Please specify both"
        return
    }
    if ( (!($sltid)) -and ($slpid) )
    {
        Get-AGMErrorMessage -messagetoprint "An slpid $slpid was specified without an sltid using -sltid xxxx.    Please specify both"
        return
    }

    if (($discovery -eq $true) -and ($targethostid) -and ($mountapplianceid))
    {
        New-AGMAppDiscovery -hostid $targethostid -applianceid $mountapplianceid
        Start-Sleep -s 30
    }
    if ((!($sqlinstance)) -and ($mountapplianceid))
        {
            $sqlinstancegrab = Get-AGMApplication -filtervalue "apptype=SqlInstance&hostid=$targethostid&sourcecluster=$mountapplianceid" -limit 1 
            if ($sqlinstancegrab.appname)
            {
                $sqlinstance = $sqlinstancegrab.appname
            }
        }
    if (!($sqlinstance))
    {
        Get-AGMErrorMessage -messagetoprint "No SQL Instance name was found to mount to.  Add -discovery to have discovery run against your targethostid"
        return
    }
    
    # learn about the image
    if (!($imagename)) 
    {
        Get-AGMErrorMessage -messagetoprint "No image was found to mount"
        return
    }

    # recovery point handling
    if (($recoverypoint) -and ($recoverypoint -ne "latest"))
    {
        $recoverytime = Convert-ToUnixDate $recoverypoint
    }

    # recovery or not
    if (!($recoverdb))
    { 
        $recoverdb = "true" 
    }


    if (!($userlogins))
    {
        $userlogins = "false"
    }

    if (!($recoverymodel))
    {
        $recoverymodel = "Same as source"
    }

    if (!($overwrite))
    {
        $overwrite = "no"
    }

    
    if (!($label))
    {
        $label = ""
    }

    if ($password)
    {
        $Bytes = [System.Text.Encoding]::Unicode.GetBytes($password)
        $base64password =[Convert]::ToBase64String($Bytes)
    }


    # turn DB name into a list of selected objects
    if ($dbnamelist)
    {
        $selectedobjects = @(
            foreach ($db in $dbnamelist.Split(","))
            {
            @{
                restorableobject = $db
            }
        }
        )
        if (($dbnamelist.Split(",").count -eq 1) -and (!($dbname)))
        {
            $dbname = $dbnamelist
        }
    }
    elseif ($dbrenamelist)
    {
        $selectedobjects = @()
        foreach ($dbsplit in $dbrenamelist.Split(";"))
        {
            $sourcedb = $dbsplit.Split(",") | Select-object -First 1
            $selectedobjects = $selectedobjects + [ordered]@{
                restorableobject = $sourcedb
            }
        } 
    }
    elseif ($imagejobclass -ne "mount") 
    {
        $selectedobjects = @(
            @{
                restorableobject = $appname
            }
        )
    }


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

    if ($mountpointspervol)
    {
        $restoreobjectmappings = @(
            foreach ($mapping in $mountpointspervol.Split(","))
            {
                $firstword = $mapping.Split("=") | Select-object -First 1
                $secondword = $mapping.Split("=") | Select-object -skip 1
                [pscustomobject]@{
                    restoreobject = $firstword
                    mountpoint = $secondword}
            } 
        )
    }


    
    if (($dbname) -or ($dbrenamelist.Split(",").count -eq 2) )
    {
        if ($dbrenamelist)
        {
            $dbname = $dbrenamelist.Split(",") | Select-object -skip 1
        }
        $provisioningoptions = @(
            @{
                name = 'sqlinstance'
                value = $sqlinstance
            },
            @{
                name = 'dbname'
                value = $dbname
            },
            @{
                name = 'recover'
                value = $recoverdb
            },
            @{
                name = 'userlogins'
                value = $userlogins
            },
            @{
                name = 'recoverymodel'
                value = $recoverymodel
            },
            @{
                name = 'overwritedatabase'
                value = $overwrite
            }
        )
        # reprotect
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
        #authentication
        if ($username)
        {
            $provisioningoptions= $provisioningoptions +@{
                name = 'username'
                value = $username
            }
            $provisioningoptions= $provisioningoptions +@{
                name = 'password'
                value = $base64password
            }
        }

        $body = [ordered]@{}
        if ($label) { $body = $body + [ordered]@{ label = $label; }}
        $body = $body + [ordered]@{
            image = $imagename;
            host = @{id=$targethostid}
            provisioningoptions = $provisioningoptions
            appaware = "true";
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
        if ($recoverytime)
        {
            $body = $body + [ordered]@{ recoverytime = [string]$recoverytime }
        }
        if ($mountmode)
        {
            $body = $body + [ordered]@{ physicalrdm = $physicalrdm }
            $body = $body + [ordered]@{ rdmmode = $rdmmode }
        }
        if ($restoreobjectmappings)
        {
            $body = $body + @{ restoreobjectmappings = $restoreobjectmappings }
        }
        if (($perfoption) -and ($imagejobclass -eq "OnVault")) { $body = $body +@{ rehydrationmode = $perfoption } }
    }
    else
    {
        if ((!($dbnamelist)) -and (!($dbrenamelist)))
        {
            Get-AGMErrorMessage -messagetoprint "Neither dbnamelist or dbrenamelist was specified.   Please specify  or dbrenamelist to identify which DBs to mount"
            return
        }
        if (!($consistencygroupname)) 
        {
            Get-AGMErrorMessage -messagetoprint "A consistencygroup was not specified"
            return
        }

        $provisioningoptions = @()
        if ($consistencygroupname)
        {
            $provisioningoptions = $provisioningoptions +
                [ordered]@{
                    name = 'ConsistencyGroupName'
                    value = $consistencygroupname
                }
        }
        if ($dbnameprefix -ne "")
        {
            $provisioningoptions= $provisioningoptions + @{
                name = 'dbnameprefix'
                value = $dbnameprefix
            }
        }
        if ($dbnamesuffix -ne "")
        {
            $provisioningoptions= $provisioningoptions + @{
                name = 'dbnamesuffix'
                value = $dbnamesuffix
            }
        }
        if ($dbrenamelist)
        {
            foreach ($dbsplit in $dbrenamelist.Split(";"))
            {
                $sourcedb = $dbsplit.Split(",") | Select-object -First 1
                $targetdb = $dbsplit.Split(",") | Select-object -skip 1
                
                $targetvalue = @{
                    name = 'TARGET_DATABASE_NAME'
                    value = $targetdb 
                }
                $provisioningoptions = $provisioningoptions +[ordered]@{
                    name = 'restorableobject'
                    value = $sourcedb       
                    values = @( $targetvalue )
                }
            }   
        } 
        $provisioningoptions= $provisioningoptions + @{
            name = 'sqlinstance'
            value = $sqlinstance
        }
        $provisioningoptions= $provisioningoptions +@{
            name = 'recover'
            value = $recoverdb
        }
        $provisioningoptions= $provisioningoptions +@{
            name = 'userlogins'
            value = $userlogins
        }
        $provisioningoptions= $provisioningoptions +@{
            name = 'recoverymodel'
            value = $recoverymodel
        }
        $provisioningoptions= $provisioningoptions +@{
            name = 'overwritedatabase'
            value = $overwrite
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
        $body = [ordered]@{}
        if ($label) { $body = $body + [ordered]@{ label = $label; }}
        if ($mountmode)
        {
            $body = $body + [ordered]@{ physicalrdm = $physicalrdm }
            $body = $body + [ordered]@{ rdmmode = $rdmmode }
        }
        $body = $body + [ordered]@{
            image = $imagename;
            host = @{id=$targethostid};
            selectedobjects = $selectedobjects
            provisioningoptions = $provisioningoptions
            appaware = "true";
            migratevm = "false";
        }
        if ($restoreoptions)
        {
            $body = $body + [ordered]@{ restoreoptions = $restoreoptions }
        }
        if ($recoverytime)
        {
            $body = $body + [ordered]@{ recoverytime = [string]$recoverytime }
        }
        if ($restoreobjectmappings)
        {
            $body = $body + [ordered]@{ restoreobjectmappings = $restoreobjectmappings }
        }
        if (($perfoption) -and ($imagejobclass -eq "OnVault")) { $body = $body +@{ rehydrationmode = $perfoption } }
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
