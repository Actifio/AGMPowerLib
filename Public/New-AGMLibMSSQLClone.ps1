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


Function New-AGMLibMSSQLClone ([string]$appid,[string]$targethostid,[string]$cloneapplianceid,[string]$imagename,[string]$imageid,[string]$targethostname,[string]$appname,[string]$sqlinstance,[string]$dbname,[string]$recoverypoint,[string]$recoverymodel,[string]$overwrite,[string]$dbnamelist,[string]$dbrenamelist,[string]$recoverdb,[string]$userlogins,[string]$username,[string]$password,[string]$base64password,[switch][alias("d")]$discovery,[switch][alias("g")]$guided,[switch][alias("m")]$monitor,[switch][alias("w")]$wait,[switch]$renamedatabasefiles,[switch]$volumes,[switch]$files,[string]$restorelist,[switch]$usesourcelocation,[switch]$jsonprint) 
{
    <#
    .SYNOPSIS
    Clones an MS SQL Image

    .EXAMPLE
    New-AGMLibMSSQLClone 
    You will be offered guided mode

    .EXAMPLE
    New-AGMLibMSSQLClone -appid 50322 -cloneapplianceid 143112195179  -targethostid 51090 -sqlinstance "WIN-TARGET\SQLEXPRESS" -dbname "AdventureWorks2019" 
    Clone the latest snapshot of a SQL Server database to specified host using specified appliance.  

    .EXAMPLE
    New-AGMLibMSSQLClone -appid 50318 -cloneapplianceid 143112195179 -targethostid 51090 -sqlinstance "WIN-TARGET\SQLEXPRESS" -dbrenamelist "CRM,CRM1"
    Clones the latest snapshot of a SQL Instance, cloning the CRM database but renaming it to CRM1 to specified host using specified appliance.

    .EXAMPLE
    New-AGMLibMSSQLClone -appid 50318 -cloneapplianceid 143112195179 -targethostid 51090 -sqlinstance "WIN-TARGET\SQLEXPRESS" -dbrenamelist "AdventureWorks2019,test1;CRM,test2"
    Clone the latest snapshot of a SQL Instance, cloning two databases but changing the target DB names.

    .EXAMPLE
    New-AGMLibMSSQLClone -appid 50318 -cloneapplianceid 143112195179 -targethostid 51090 -sqlinstance "WIN-TARGET\SQLEXPRESS" -dbnamelist "AdventureWorks2019,CRM" 
    Clone the latest snapshot of a SQL Instance, cloneing two databases but not changing the target DB names (dbnamelist, not dbrenamelist).  

    .EXAMPLE
    New-AGMLibMSSQLClone -appid 50318 -cloneapplianceid 143112195179 -targethostid 51090  -files  -restorelist "SQL_smalldb.mdf,D:\Data,d:\avtest1;SQL_smalldb_log.ldf,E:\Logs,e:\avtest1"

    Starts a clone 
    Files will be renamed to match the new database name.
    Because "-files" was specified, the -restorelist must contain the file name, the source location and the targetlocation.
    Each file is separated by a semicolon,  the three fields for each file are comma separated.
    In this example, the file SQL_smalldb.mdf found in D:\Data will be cloned to d:\avtest1
    In this example, the file SQL_smalldb_log found in E:\Logs will be cloned to e:\avtest1
    The order of the fields must be "filename,sourcefolder,targetfolder" so for two files "filename1,source1,target1;filename2,source2,target2"

    .EXAMPLE    
    New-AGMLibMSSQLClone -appid 50318 -cloneapplianceid 143112195179 -targethostid 51090 -volumes -restorelist "D:\,K:\;E:\,M:\"

    Starts a clone
    Files will be renamed to match the new database name.
    Because "-volumes" was specified, the -restorelist must contain the source drive letter and the target drive letter.
    Each drive is separated by a semicolon,  the two fields for each drive are comma separated.
    In this example the D:\ files will be cloned to the K:\
    In this example the E:\ files will be cloned to the M:\
    The order of the fields must be "sourcedrive,targetdrive" so for two drives "sourcedrive1,targetdrive1;sourcedrive2,targetdrive2"


    .DESCRIPTION
    A function to clone MS SQL Image

    * Image selection can be done three ways:

    1)  Run this command in guided mode to learn the available images and select one
    2)  Learn the imagename and specify that as part of the command with -imagename
    3)  Learn the Appid and Cluster ID for the appliance that will clone the image and then use -appid and -cloneapplianceid 
    This will use the latest snapshot, StreamSnap or OnVault image on that appliance

    Note default values don't need to specified. So for instance these are both unnecessary:  -recoverdb true -userlogins false

    * clone host options:
    -sqlinstance  The SQL instance on the host we are cloning into
    -targethostname  The target host specified by name. Ideally use the next option
    -targethostid  The target host specified by id

    *  cloneed app names
    -dbname  If cloning only one DB use this option.  This is the name of the new database that will be created.
    -dbnamelist  If cloning more than one DB, use this comma separated.  It is better to use -dbrenamelist 
    -dbrenamelist  Semicolon separated list of comma separated source db and target db.  So if we have two source DBs, prod1 and prod2 and we clone them as dev1 and dev2 then:   prod1,dev1;prod2,dev2
    -dbnamesuffix option to add a suffix.  Use this with -dbnamelist
    -dbnameprefix option to add a prefix.  Use this with -dbnamelist
    
    * Other options

    -mountpointperimage
    -recoverypoint  The point in time to roll forward to, in ISO8601 format like 2020-09-02 19:00:02. Or the word 'latest' to apply all available logs
    -recoverymodel   use either:   "Same as source" (default) or "Simple" or "Full" or "Bulk logged"
    -overwrite    use either:   "no" (default)  "stale" or "yes"
    -recoverdb    true=Recover database after restore (default) false=Don't recovery database after restore
    -userlogins   false=Don't recover user logins(default)    true=Recover User Logins
    -discovery     This is a switch, so if specified will run application discovery on the selected targethostid
    -cloneapplianceid XXXX    Runs the clone on the specified appliance
#   -perfoption    Used only with OnVault images, you can specify either:  StorageOptimized, Balanced, PerformanceOptimized or MaximumPerformance

    * Reprotection:

    -sltid xxxx (short for Service Level Template ID) - if specified along with an slpid, will reprotect the cloned child app with the specified template and profile
    -slpid yyyy (short for Service Level Profile ID) - if specified along with an sltid, will reprotect the cloned child app with the specified template and profile

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
    -mapdiskstoallesxhosts   Either true to do this or false to not do this. Default is false.  

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
            $cloneapplianceid = $imagegrab.cluster.clusterid
            $imagejobclass = $imagegrab.jobclass    
            $vollist = $imagegrab.restorableobjects.volumeinfo.logicalname | sort-object -unique
            $filelist = $imagegrab.restorableobjects.fileinfo | sort-object filepath,filename
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
            $cloneapplianceid = $imagegrab.cluster.clusterid
            $imagejobclass = $imagegrab.jobclass   
            $vollist = $imagegrab.restorableobjects.volumeinfo.logicalname | sort-object -unique
            $filelist = $imagegrab.restorableobjects.fileinfo | sort-object filepath,filename
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
         # first we need to work out which appliance we are cloning from 
         $appliancegrab = Get-AGMAppliance | select-object name,clusterid | sort-object name
         if ($appliancegrab.count -eq 0)
         {
             Get-AGMErrorMessage -messagetoprint "Failed to find any appliances to list."
             return
         }
         if ($appliancegrab.name.count -eq 1)
         {
             $cloneapplianceid = $appliancegrab.clusterid
             $cloneappliancename =  $appliancegrab.name
         }
         else
         {
             Clear-Host
             write-host "Appliance selection menu - which Appliance will run this clone"
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
                 [int]$appselection = Read-Host "Please select an Appliance to clone from (1-$listmax)"
                 if ($appselection -lt 1 -or $appselection -gt $listmax)
                 {
                     Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                 } 
                 else
                 {
                     break
                 }
             }
             $cloneapplianceid =  $appliancegrab.clusterid[($appselection - 1)]
             $cloneappliancename =  $appliancegrab.name[($appselection - 1)]
         }
        Clear-Host
        Write-Host "What App Type do you want to work with:"
        Write-Host "1`: SQL Server (default)"
        Write-Host "2`: SQL Instance"
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
        if ($userselectionapps -eq "" -or $userselectionapps -eq 1)  { $applist = Get-AGMApplication -filtervalue "managed=true&apptype=$apptype&sourcecluster=$cloneapplianceid" | sort-object appname }
        if ($userselectionapps -eq 2) { $applist = Get-AGMApplication -filtervalue "managed=false&apptype=$apptype&sourcecluster=$cloneapplianceid" | sort-object appname  }
        if ($userselectionapps -eq 3) { $applist = Get-AGMApplication -filtervalue "apptype=$apptype&sourcecluster!$cloneapplianceid&clusterid=$cloneapplianceid" | sort-object appname }
        if ($applist.id.count -eq 0)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to find any $apptype apps"
            return
        }
        $i = 1
        Clear-Host
        Write-host "Application selection menu"
        Write-host ""
        foreach ($app in $applist)
        { 
            $applistname = $app.appname
            $appliance = $app.cluster.name 
            if ($userselection -eq 1)
            {
                $pathname = $app.pathname
                Write-Host -Object "$i`: $pathname`\$applistname ($appliance)"
            }
            else {
                Write-Host -Object "$i`: $applistname ($appliance)"
            }
            
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
    }
    
    # this if for guided menu
    if ($guided)
    {
        
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
                $imagegrab = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&targetuds=$cloneapplianceid" -sort "consistencydate:desc,jobclasscode:desc" -limit 1
                if ($imagegrab.id.count -eq 0)
                {
                    Get-AGMErrorMessage -messagetoprint "Failed to fetch any Images for appid $appid on target appliance $cloneapplianceid"
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
                    $cloneapplianceid = $imagegrab.cluster.clusterid
                    $cloneappliancename = $imagegrab.cluster.name
                    $vollist = $imagegrab.restorableobjects.volumeinfo.logicalname | sort-object -unique
                    $filelist = $imagegrab.restorableobjects.fileinfo | sort-object filepath,filename
                } 
            }   
            
            if ($rposelection -eq 2)
                {
                $imagelist1 = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&targetuds=$cloneapplianceid"  | select-object -Property backupname,consistencydate,endpit,id,jobclass,cluster | Sort-Object consistencydate,jobclass
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
                    $cloneapplianceid = $imagegrab.cluster.clusterid
                    $cloneappliancename = $imagegrab.cluster.name
                    $vollist = $imagegrab.restorableobjects.volumeinfo.logicalname | sort-object -unique
                    $filelist = $imagegrab.restorableobjects.fileinfo | sort-object filepath,filename
                    write-host "Found one $imagejobclass image $imagename, consistency date $consistencydate on $cloneappliancename"
                } 
                else
                {
                    Clear-Host
                    Write-Host "Image list.  Choose the best jobclass and consistency date on the clone appliance"
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
                    $cloneapplianceid = $imagegrab.cluster.clusterid
                    $cloneappliancename = $imagegrab.cluster.name
                    $imagejobclass = $imagegrab.jobclass   
                    $vollist = $imagegrab.restorableobjects.volumeinfo.logicalname | sort-object -unique
                    $filelist = $imagegrab.restorableobjects.fileinfo | sort-object filepath,filename
                }
            }
        }

        
        # now we check the log date
        if ($endpit)
        {
            write-host ""
            Write-Host "Log handling"
            Write-Host "1`: Clone without applying logs (default)"
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
            $hostgrab1 = Get-AGMApplication -filtervalue "apptype=SqlInstance&sourcecluster=$cloneapplianceid"
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
                $hostgrab = Get-AGMHost -filtervalue "sourcecluster=$cloneapplianceid" | sort-object name 
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
                write-host "Running discovery on selected host ID $targethostid on Appliance ID $cloneapplianceid"
                New-AGMAppDiscovery -hostid $targethostid -applianceid $cloneapplianceid
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

        # now we determine the instance to clone to
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
                $clonedname =
                [string]$clonedname = Read-Host "Target name for $db (press enter to skip)"
                if ($clonedname)
                {
                    if ($dbrenamelist)
                    {
                        $dbrenamelist = $dbrenamelist + ";$db,$clonedname"
                    } else {
                        $dbrenamelist = "$db,$clonedname"
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
        # rename files
        write-host ""
        Write-Host "File rename"
        Write-Host "1`: Rename files to match database name(default)"
        Write-Host "2`: Don't rename files to match database name"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $renamedatabasefiles = $true  }
        if ($userselection -eq 2) {  $renamedatabasefiles = $false }

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

        $userselection = 
        Write-Host ""
        Write-Host "Select file destination for migrated files"
        Write-Host "1`: Copy files to the same drive/path as they were on the source (default)"
        Write-Host "2`: Choose new file locations at the volume level"
        Write-Host "3`: Choose new locations at the file level"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-3)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $usesourcelocation = $TRUE }
        if ($userselection -eq 2) 
        {
            Write-host "`n For each volume please specify a new volume"
            $restorelist = ""
            
            write-host ""
            foreach ($vol in $vollist)
            {
                $targetlocation = ""
                $targetlocation = read-host "Source: $($vol)   Target"
                if ($targetlocation -eq "")
                { 
                    $targetlocation = $vol
                }
                $restorelist = $restorelist + ";" + $vol + "," + $targetlocation 
            }
            $restorelist = $restorelist.Substring(1)
            $volumes = $TRUE
        }
        if ($userselection -eq 3) 
        {
            $restorelist = ""
            Write-host "`n For each file please specify a new location:"
            
            write-host ""
            foreach ($file in $filelist)
            {
                $targetlocation = ""
                $targetlocation = read-host "File: $($file.filename)   Source: $($file.filepath)   Target Path"
                if ($targetlocation -eq "")
                { 
                    $targetlocation = $file.filepath
                }
                $restorelist = $restorelist + ";" + $file.filename + "," + $file.filepath + "," + $targetlocation 
            }
            $restorelist = $restorelist.Substring(1)
            $files = $TRUE
        }


        #volume info section
        $logicalnamelist = $restorableobjects.volumeinfo | select-object logicalname,capacity,uniqueid | sort-object logicalname | Get-Unique -asstring
        Clear-Host  
        

        if ($logicalnamelist.count -eq 1)
        {
            Write-Host "This image has only one drive. You can change clone point used or allow the Connector to determine this"
            Write-Host ""
#            $mountpointperimage = ""
#            $mountpointperimage = Read-Host "Clone Location (optional)"
            
        }
        if ($logicalnamelist.count -gt 1)
        {
            Write-Host "This image has more than one drive. You can enter a Clone Location, or press enter to set Clone points per drive. "
            Write-Host ""
        }

        # we are done
       Clear-Host  
        Write-Host "Guided selection is complete.  The values entered would result in the following command:"
        Write-Host ""
      
        Write-Host -nonewline "New-AGMLibMSSQLClone -appid $appid -cloneapplianceid $cloneapplianceid  -targethostid $targethostid -sqlinstance `"$sqlinstance`""
        if ($rposelection -eq 2 )
        {
            Write-Host -nonewline "-imagename `"$imagename`""
        }
        if ($renamedatabasefiles -eq $true) {
            Write-Host -nonewline " -renamedatabasefiles"
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
        if ($username)
        {
            Write-Host -nonewline " -username $username -base64password `"$base64password`""
        }
        if ($volumes)
        {
            Write-Host -nonewline " -volumes"
        }
        if ($files)
        {
            Write-Host -nonewline " -files"
        }
        if ($usesourcelocation)
        {
            Write-Host -nonewline " -usesourcelocation"
        }
        if ($restorelist)
        {
            Write-Host -nonewline " -restorelist `"$restorelist`""
        }

        Write-Host ""
        Write-Host "1`: Run the command now (default)"
        Write-Host "2`: Exit without running the command"
        $userchoice = Read-Host "Please select from this list (1-2)"
        if ($userchoice -eq 2)
        {
            return
        }

    }
        
    if ($targethostid -eq "")
    {
        Get-AGMErrorMessage -messagetoprint "Cannot proceed without a targethostid or targethostname"
        return
    }

    if (($appid) -and ($cloneapplianceid) -and (!($imageid)))
    {
        # if we are not running guided mode but we have an appid without imageid, then lets get the latest image on the cloneappliance ID
        $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$cloneapplianceid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:asc" -limit 1
        if ($imagegrab.id.count -eq 1)
        {   
            $imageid = $imagegrab.id
            $imagename = $imagegrab.backupname
            $imagejobclass = $imagegrab.jobclass
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot, StreamSnap or OnVault Image for appid $appid on appliance with clusterID $cloneapplianceid"
            return
        }
    }


    if (($discovery -eq $true) -and ($targethostid) -and ($cloneapplianceid))
    {
        New-AGMAppDiscovery -hostid $targethostid -applianceid $cloneapplianceid
        Start-Sleep -s 30
    }
    if ((!($sqlinstance)) -and ($cloneapplianceid))
        {
            $sqlinstancegrab = Get-AGMApplication -filtervalue "apptype=SqlInstance&hostid=$targethostid&sourcecluster=$cloneapplianceid" -limit 1 
            if ($sqlinstancegrab.appname)
            {
                $sqlinstance = $sqlinstancegrab.appname
            }
        }
    if (!($sqlinstance))
    {
        Get-AGMErrorMessage -messagetoprint "No SQL Instance name was found to clone to.  Add -discovery to have discovery run against your targethostid"
        return
    }
    
    # learn about the image
    if (!($imagename)) 
    {
        Get-AGMErrorMessage -messagetoprint "No image was found to clone"
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


    if (!($restorelist))
    { 
        $usesourcelocation = $TRUE
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
    elseif ($imagejobclass -ne "clone") 
    {
        $selectedobjects = @(
            @{
                restorableobject = $appname
            }
        )
    }


    # we are here if we have a single DB to wrork with
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
        if ($renamedatabasefiles -eq $true)
        {
            $provisioningoptions= $provisioningoptions +@{
                name = 'renamedatabasefiles'
                value = 'true'
            }
        } else {
            $provisioningoptions= $provisioningoptions +@{
                name = 'renamedatabasefiles'
                value = 'false'
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
        $body = $body + [ordered]@{
            image = $imagename;
            host = @{id=$targethostid}
            provisioningoptions = $provisioningoptions
            appaware = "true";
            migratevm = "false";
        }

        if ($selectedobjects)
        {
            $body = $body + [ordered]@{ selectedobjects = $selectedobjects }
        }
        if ($recoverytime)
        {
            $body = $body + [ordered]@{ recoverytime = [string]$recoverytime }
        }

        if ($restoreobjectmappings)
        {
            $body = $body + @{ restoreobjectmappings = $restoreobjectmappings }
        }
        if ($usesourcelocation)
        {
            $body += @{  restorelocation = @{ type = "usesourcelocation" } }
        }
        if ($volumes)
        {
            foreach ($volume in $restorelist.split(";"))
            {
                $mapping += @( [ordered]@{ name = $volume.split(",")[0] ; source = $volume.split(",")[0] ; target = $volume.split(",")[1] } ) 
            }
            $restorelocation += @{type = "volumes"} 
            $restorelocation += @{mapping = $mapping}
            $body += @{ restorelocation = $restorelocation }
        }
        if ($files)
        {
            foreach ($file in $restorelist.split(";"))
            {
                $mapping += @( [ordered]@{ name = $file.split(",")[0] ; source = $file.split(",")[1] ; target = $file.split(",")[2] } ) 
            }
            $restorelocation += @{ type = "files" }
            $restorelocation += @{ mapping = $mapping } 
            $body += @{ restorelocation = $restorelocation }
        }


    }
    else
    {
        if ((!($dbnamelist)) -and (!($dbrenamelist)))
        {
            Get-AGMErrorMessage -messagetoprint "Neither dbnamelist or dbrenamelist was specified. Please specify or dbrenamelist to identify which DBs to clone"
            return
        }


        $provisioningoptions = @()


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
        if ($renamedatabasefiles -eq $true)
        {
            $provisioningoptions= $provisioningoptions +@{
                name = 'renamedatabasefiles'
                value = 'true'
            }
        } else {
            $provisioningoptions= $provisioningoptions +@{
                name = 'renamedatabasefiles'
                value = 'false'
            }
        }

        $body = [ordered]@{}

        $body = $body + [ordered]@{
            image = $imagename;
            host = @{id=$targethostid};
            selectedobjects = $selectedobjects
            provisioningoptions = $provisioningoptions
            appaware = "true";
            migratevm = "false";
        }

        if ($recoverytime)
        {
            $body = $body + [ordered]@{ recoverytime = [string]$recoverytime }
        }
        if ($restoreobjectmappings)
        {
            $body = $body + [ordered]@{ restoreobjectmappings = $restoreobjectmappings }
        }
        if ($usesourcelocation)
        {
            $body += @{  restorelocation = @{ type = "usesourcelocation" } }
        }
        if ($volumes)
        {
            foreach ($volume in $restorelist.split(";"))
            {
                $mapping += @( [ordered]@{ name = $volume.split(",")[0] ; source = $volume.split(",")[0] ; target = $volume.split(",")[1] } ) 
            }
            $restorelocation += @{type = "volumes"} 
            $restorelocation += @{mapping = $mapping}
            $body += @{ restorelocation = $restorelocation }
        }
        if ($files)
        {
            foreach ($file in $restorelist.split(";"))
            {
                $mapping += @( [ordered]@{ name = $file.split(",")[0] ; source = $file.split(",")[1] ; target = $file.split(",")[2] } ) 
            }
            $restorelocation += @{ type = "files" }
            $restorelocation += @{ mapping = $mapping } 
            $body += @{ restorelocation = $restorelocation }
        }
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
        Write-host "Post-AGMAPIData  -endpoint /backup/$imageid/clone -body `'$compressedjson`'"
        return
    }

    Post-AGMAPIData  -endpoint /backup/$imageid/clone -body $json

    if ($wait)
    {
        Start-Sleep -s 15
        $i=1
        while ($i -lt 9)
        {
            Clear-Host
            write-host "Checking for a running job for appid $appid against targethostname $targethostname"
            $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=7&isscheduled=False&targethost=$targethostname" -sort queuedate:desc -limit 1 
            if (!($jobgrab.jobname))
            {
                write-host "Job not running yet, will wait 15 seconds and check again. Check $i of 8"
                Start-Sleep -s 15
                $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=7&isscheduled=False&targethost=$targethostname" -sort queuedate:desc -limit 1 
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
