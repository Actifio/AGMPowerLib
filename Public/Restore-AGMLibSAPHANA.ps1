
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

Function Restore-AGMLibSAPHANA ([string]$appid,[string]$targethostid,[string]$mountapplianceid,[string]$imagename,[string]$imageid,[string]$targethostname,[string]$appname,[string]$recoverypoint,[string]$label,[string]$dbsid,[string]$userstorekey,[string]$jsonprint,[switch][alias("g")]$guided,[switch]$preflight,[switch]$replacesource,[switch]$copyhdbstorekey) 
{
    <#
    .SYNOPSIS
    Restores a SAP HANA Database Image

    .EXAMPLE
    Restore-AGMLibSAPHANA 
    You will be prompted through a guided menu

    .EXAMPLE
    Restore-AGMLibSAPHANA -appid 577110 -mountapplianceid 141767697828 -targethostid 483699 -dbsid "TGT" -userstorekey "ACTBACKUP"
    Restores an SAP HANA Database with specified SID 

    .DESCRIPTION
    A function to restore a SAP HANA database

    * Image selection can be done three ways:

    1)  Run this command in guided mode to learn the available images and select one
    2)  Learn the imagename and specify that as part of the command with -imagename
    3)  Learn the Appid and Cluster ID for the appliance that will restore the image and then use -appid and -mountapplianceid 
    This will use the latest snapshot, StreamSnap or OnVault image on that appliance

    Note default values don't need to specified.  

    * label
    -label   Label for restore, recommended

    * Restore host options:
    -targethostname   The target host specified by name.  Ideally use the next option
    -targethostid   The target host specified by id

    *  required settings
    -userstorekey xxxx   name of the HANA database user store key on the target server where a new SAP HANA Instance will get created.

    
    * Other options

    -recoverypoint  The point in time to roll forward to, in ISO8601 format like 2020-09-02 19:00:02

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
            $mountapplianceid = $imagegrab.cluster.clusterid   
            $dbsid = ($imagegrab.provisioningoptions | where-object {($_.key -eq "dbsid")}).value
            if (!($userstorekey)) { $userstorekey = ($imagegrab.provisioningoptions | where-object {($_.key -eq "DBUSER")}).value }
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
            $mountapplianceid = $imagegrab.cluster.clusterid
            $dbsid = ($imagegrab.provisioningoptions | where-object {($_.key -eq "dbsid")}).value
            if (!($userstorekey)) { $userstorekey = ($imagegrab.provisioningoptions | where-object {($_.key -eq "DBUSER")}).value }
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
            write-host "Appliance selection menu - which Appliance will run this restore"
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
                [int]$appselection = Read-Host "Please select the Appliance that will run the restore (1-$listmax)"
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
                    $jobclass = $imagegrab.jobclass
                    $mountapplianceid = $imagegrab.cluster.clusterid
                    $mountappliancename = $imagegrab.cluster.name
                    $sourcehostname = $imagegrab.host.hostname
                    $sourcehostid = $imagegrab.host.id
                    $sourcedbuser = ($imagegrab.provisioningoptions | where-object {($_.key -eq "DBUSER")}).value
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
                    $imagegrab = Get-AGMImage -id $($imagelist1).id
                    $imagename = $imagegrab.backupname                
                    $consistencydate = $imagegrab.consistencydate
                    $endpit = $imagegrab.endpit
                    $appname = $imagegrab.appname
                    $appid = $imagegrab.application.id
                    $apptype = $imagegrab.apptype      
                    $jobclass = $imagegrab.jobclass
                    $mountapplianceid = $imagegrab.cluster.clusterid
                    $mountappliancename = $imagegrab.cluster.name
                    $sourcehostname = $imagegrab.host.hostname
                    $sourcehostid = $imagegrab.host.id

                    $sourcedbuser = ($imagegrab.provisioningoptions | where-object {($_.key -eq "DBUSER")}).value
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
                    $mountapplianceid = $imagegrab.cluster.clusterid
                    $mountappliancename = $imagegrab.cluster.name 
                    $sourcehostname = $imagegrab.host.hostname
                    $sourcehostid = $imagegrab.host.id
                    $sourcedbuser = ($imagegrab.provisioningoptions | where-object {($_.key -eq "DBUSER")}).value
                }
             }
        }
        
        # now we check the log date
        if ($endpit)
        {
            write-host ""
            $recoverypoint = Read-Host "Roll forward time (hitting enter to use all available logs)`: $consistencydate to $endpit"
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
            else {
                $recoverypoint = $endpit
            }
        }
        


        if ( (!($targethostname)) -and (!($targethostid)))
        {
            # target host
            if ($AGMToken)
            {
                write-host ""
                $userselection = ""
                Write-Host "Target host selection"
                Write-Host "1`: Restore back to the source host (default)"
                Write-Host "2`: Restore to a new target"
                Write-Host ""
                While ($true) 
                {
                    [int]$targetselection = Read-Host "Please select from this list (1-2)"
                    if ($targetselection -eq "") { $targetselection = 1 }
                    if ($targetselection -lt 1 -or $targetselection -gt 2)
                    {
                        Write-Host -Object "Invalid selection. Please enter a number in range [1-2]"
                    } 
                    else
                    {
                        break
                    }
                }
            }
            else {
                $targetselection = 1
            }
            if ($targetselection -eq 1)
            {
                $targethostname = $sourcehostname
                $targethostid = $sourcehostid
            }
            else 
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

                 # target host
                write-host ""
                $replacehostselection = ""
                Write-Host "REPLACE ORIGINAL APPLICATION IDENTITY"
                Write-Host "1`: No (default)"
                Write-Host "2`: Yes"
                Write-Host ""
                [int]$replacehostselection = Read-Host "Please select from this list (1-2)"

                if ($replacehostselection -eq "") { $replacehostselection = 1 }
                if ($replacehostselection -eq 1) { $replacesource = $false }
                if ($replacehostselection -eq 2) { $replacesource = $true }
            }
        }
    

        write-host ""

        $userstorekey = read-host "SAP HANA Target user store key or press enter to use $sourcedbuser"
        if ($userstorekey -eq "")
        {
            $userstorekey = $sourcedbuser
        } 
        if (!($AGMToken))
        {
            write-host ""
            $userselection = ""
            Write-Host "Copy HDB User Store Key to target Host"
            Write-Host "1`: No (default)"
            Write-Host "2`: Yes"
            Write-Host ""
            [int]$replacehostselection = Read-Host "Please select from this list (1-2)"

            if ($replacehostselection -eq "") { $replacehostselection = 1 }
            if ($replacehostselection -eq 1) { $copyhdbstorekey = $false }
            if ($replacehostselection -eq 2) { $copyhdbstorekey = $true }
        }

        Write-host ""

    
        # we are done
       Clear-Host  
        Write-Host "Guided selection is complete. The values entered resulted in the following commands."
        if ($AGMToken)
        {
            Write-host "You should run the pre-flight first (first command) to validate restore will run without error before running the actual restore (second command)."
            Write-Host ""
        
            Write-Host -nonewline "Restore-AGMLibSAPHANA -appid $appid -mountapplianceid $mountapplianceid -imagename $imagename -targethostid $targethostid -userstorekey `"$userstorekey`""
            if ($label)
            {
                Write-Host -nonewline " -label `"$label`""
            }
            if ($recoverypoint)
            {
                Write-Host -nonewline " -recoverypoint `"$recoverypoint`""
            }
            if ($replacesource -eq $true)
            {
                Write-Host -nonewline " -replacesource"
            }
            Write-Host -nonewline " -preflight"
        }
        Write-Host ""
        Write-Host -nonewline "Restore-AGMLibSAPHANA -appid $appid -mountapplianceid $mountapplianceid -imagename $imagename -targethostid $targethostid  -userstorekey `"$userstorekey`""
        if ($label)
        {
            Write-Host -nonewline " -label `"$label`""
        }
        if ($recoverypoint)
        {
            Write-Host -nonewline " -recoverypoint `"$recoverypoint`""
        }
        if ($replacesource -eq $true)
        {
            Write-Host -nonewline " -replacesource"
        }
        if ($copyhdbstorekey -eq $true)
        {
            Write-Host -nonewline " -copyhdbstorekey"
        }
        Write-Host ""
        Read-Host "Please enter to exit"
        return
    }



    if (($appid) -and ($mountapplianceid) -and (!($imageid)))
    {
        # if we are not running guided mode but we have an appid without imageid, then lets get the latest image on the mountappliance ID
        $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:asc" -limit 1
        if ($imagegrab.id.count -eq 1)
        {   
            $imagegrab1 = Get-AGMImage -id $($imagegrab).id
            $imageid = $imagegrab1.id
            $imagename = $imagegrab1.backupname
            $targethostid = $imagegrab1.host.id
            
            $dbsid = ($imagegrab1.provisioningoptions | where-object {($_.key -eq "dbsid")}).value
            if (!($userstorekey)) { $userstorekey = ($imagegrab1.provisioningoptions | where-object {($_.key -eq "DBUSER")}).value }
            if ($imagegrab1.endpit) { $recoverypoint = $imagegrab1.endpit }
        } 
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot, StreamSnap or OnVault Image for appid $appid on appliance with clusterID $mountapplianceid"
            return
        }
    }

    if ($targethostid -eq "")
    {
        Get-AGMErrorMessage -messagetoprint "Cannot proceed without a targethostid or targethostname"
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


    if (!($userstorekey))
    {
        Get-AGMErrorMessage -messagetoprint "No HANA user store key was specified"
        return
    }


    $provisioningoptions = @()
    $provisioningoptions = $provisioningoptions +[ordered]@{
        name = 'dbsid'
        value = $dbsid
    }
    $provisioningoptions = $provisioningoptions +[ordered]@{
        name = 'DBUSER'
        value = $userstorekey
    }
    
    $body = [ordered]@{}
    if ($label) { $body = $body + [ordered]@{ label = $label; }}
    if ($AGMToken)
    {
        if ($replacesource -eq $true) { $body = $body + [ordered]@{ replacesource = $true; } } else { $body = $body + [ordered]@{ replacesource = $false; } }
        $body = $body + [ordered]@{
            host = @{id=$targethostid};
            hostclusterid = $mountapplianceid;
            provisioningoptions = $provisioningoptions;
        }
    }
    else {
        $restoreoptions = @()
        $restoreoptions = $restoreoptions +[ordered]@{
            name = 'copyhdbstorekey'
            value = $copyhdbstorekey
        }
        $restoreoptions = $restoreoptions +[ordered]@{
            name = 'restoreuserstorekey'
            value = $userstorekey
        }
        
        $body = $body + [ordered]@{
            restoreoptions = $restoreoptions;
            restoreobjectmappings = $restoreobjectmappings;
            systemstateoptions = $systemstateoptions;
        }
    }
    if ($recoverytime)
    {
        $body = $body +[ordered]@{ recoverytime = [string]$recoverytime }
    }
    

    $json = $body | ConvertTo-Json -depth 10


    if ($jsonprint -eq "yes")
    {
        $compressedjson = $body | ConvertTo-Json -compress -depth 10
        Write-host "This is the final command:"
        Write-host ""
        Write-host "Post-AGMAPIData -endpoint /backup/$imageid/restore -body `'$compressedjson`'"
        return
    }
    $json
    return

    if ($preflight)
    {
        $preflighttest = Post-AGMAPIData  -endpoint /backup/$imageid/restorepreflight -body $json
        if ($preflighttest.testlist)
        {
            $preflighttest.testlist
        }
        else {
            $preflighttest
        }
    }
    else {
        Post-AGMAPIData  -endpoint /backup/$imageid/restore -body $json
    }
}