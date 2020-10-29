Function New-AGMLibOracleMount ([string]$appid,[string]$targethostid,[string]$mountapplianceid,[string]$imagename,[string]$imageid,[string]$targethostname,[string]$appname,[string]$dbname,[string]$username,[string]$orahome,[string]$recoverypoint,[string]$sltid,[string]$slpid,[string]$label,[string]$mountmode,[string]$mapdiskstoallesxhosts,
[switch]$nonid,[switch]$noarchivemode,[switch]$clearlog,[switch]$notnsupdate,[switch]$nooratabupdate,[switch]$CLEAR_OS_AUTHENT_PREFIX,[switch]$norrecovery,[switch]$useexistingorapw,[string]$tnsadmindir, 
[string]$password,
[string]$base64password,
[int]$totalmemory,
[int]$sgapct,
[int]$redosize,
[int]$shared_pool_size,
[int]$db_cache_size,
[int]$db_recovery_file_dest_size,
[int]$inmemory_size,
[string]$diagnostic_dest,
[int]$processes,
[int]$open_cursors,
[string]$tnsip,
[int]$tnsport,
[string]$tnsdomain,
[string]$pdbprefix,
[switch][alias("g")]$guided,[switch][alias("m")]$monitor,[switch][alias("w")]$wait) 
{
    <#
    .SYNOPSIS
    Mounts an Oracle Image

    .EXAMPLE
    New-AGMLibOracleMount 
    You will be prompted for Appname and target Hostname, Oracle username and home directory

    .EXAMPLE
    New-AGMLibOracleMount -imageid 56066146 -label "avtest" -targethostid 41872093 -dbname "avtest4" -username "oracle" -orahome "/home/oracle/app/oracle/product/12.2.0/dbhome_1"  -recoverypoint "2020-08-19 11:35" 

    This command mounts an image to a target host ID.

    .EXAMPLE
    New-AGMLibOracleMount -targethostid 41872093

    This command starts guided mode but with a pre learned target host ID
    Note that the host list shown by guided mode is not complete.   Use Get-AGMLibHostID to learn the targethostid 

    .DESCRIPTION
    A function to mount Oracle Images

    * Image selection can be done three ways:

    1)  Run this command in guided mode to learn the available images and select one
    2)  Learn the imagename and specify that as part of the command with -imagename
    3)  Learn the Appid and Cluster ID for the appliance that will mount the image and then use -appid and -mountapplianceid 
    This will use the latest snapshot, dedupasync, StreamSnap or OnVault image on that appliance

    Note default values don't need to specified.  So for instance these are both unnecessary:   -recoverdb true -userlogins false

    * label
    -label   Label for mount, recommended

    There are a great many variables that can be set.  To get help, use guided mode.
    
    * Username and password:
    
    -username  This is the username (mandatory).  Normally a password is not needed.
    -password  This is the password in plain text (not a good idea)
    -base64password   This is the password in base 64 encoding
    To create this:
    $password = 'passw0rd'
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($password)
    $base64password =[Convert]::ToBase64String($Bytes)

    * VMware specific options
    -mountmode    use either   nfs, vrdm or prdm
    -mapdiskstoallesxhosts   Either true to do this or false to not do this.  Default is false.  

    * Reprotection:

    -sltid xxxx (short for Service Level Template ID) - if specified along with an slpid, will reprotect the mounted child app with the specified template and profile
    -slpid yyyy (short for Service Level Profile ID) - if specified along with an sltid, will reprotect the mounted child app with the specified template and profile
    
    Note that if specify -norrecovery then your mounted DB will not be brought online.   

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
    else 
    {
        $sessiontest = (Get-AGMSession).session_id
        if ($sessiontest -ne $AGMSESSIONID)
        {
            Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
            return
        }
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
        }
    }

    if (($targethostname) -and (!($targethostid)))
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
            $mountapplianceid = $imagegrab.cluster.clusterid
        }
    }

    # if the user gave us nothing to start work, then enter guided mode
    if (( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) ) -or ($guided))
    {
        clear
        write-host "Oracle App Selection menu"
        Write-host ""
        $guided = $true
        $applist = Get-AGMApplication -filtervalue "apptype=Oracle&managed=True" | sort-object appname
        if ($applist.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "There are no Managed Oracle apps to list"
            return
        }
        if ($applist.count -eq 1)
        {
            $appname =  $applist.appname
            $appid = $applist.id
            write-host "Found one Oracle app $appname"
            write-host ""
        }
        else 
        {
            $i = 1
            foreach ($app in $applist)
            { 
                Write-Host -Object "$i`: $($app.appname)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $applist.appname.count
                [int]$appselection = Read-Host "Please select a protected App (1-$listmax)"
                if ($appselection -lt 1 -or $appselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $appname =  $applist.appname[($appselection - 1)]
            $appid = $applist.id[($appselection - 1)]
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
        Clear-Host
        Write-Host "Image selection"
        $imagelist = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&jobclass=StreamSnap&jobclass=OnVault&jobclass=dedupasync"  | select-object -Property backupname,consistencydate,endpit,id,jobclass,cluster | Sort-Object consistencydate,jobclass
        if ($imagelist.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any Images for appid $appid"
            return
        }   
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
        $mountapplianceid = $imagegrab.cluster.clusterid
        $mountappliancename = $imagegrab.cluster.name

        if ( (!($targethostname)) -and (!($targethostid)))
        {
            Clear-Host
            $hostgrab = Get-AGMHost -filtervalue "clusterid=$mountapplianceid&hosttype!VMCluster&hosttype!esxhost&hosttype!NetApp 7 Mode&hosttype!NetApp SVM&hosttype!ProxyNASBackupHost&hosttype!Isilon" | sort-object vmtype,hostname
            if ($hostgrab.id.count -eq -0)
            {
                Get-AGMErrorMessage -messagetoprint "Failed to find any hosts on $mountappliancename"
                return
            }
            Clear-Host
            Write-Host "Host List."
            $i = 1
            foreach ($hostid in $hostgrab)
            { 
                $hostid | Add-Member -NotePropertyName select -NotePropertyValue $i
                if (!($hostid.vmtype))
                {
                    $hostid | Add-Member -NotePropertyName vmtype -NotePropertyValue "Physical"
                }
                $i++
            }

            $hostgrab | select-object select,vmtype,hostname,ostype,id | Format-table *
            While ($true) 
            {
                Write-host ""
                $listmax = $hostgrab.count
                [int]$userselection = Read-Host "Please select a host (1-$listmax)"
                if ($userselection -lt 1 -or $userselection -gt $hostgrab.Length)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($hostgrab.count)]"
                } 
                else
                {
                    break
                }
            }
            $targethostid = $hostgrab.id[($userselection - 1)]
            $targethostname = $hostgrab.hostname[($userselection - 1)]
            $vmtype = $hostgrab.vmtype[($userselection - 1)]
            $transport = $hostgrab.transport[($userselection - 1)]
            $diskpref = $hostgrab.diskpref[($userselection - 1)]
            $vcenterid = $hostgrab.vcenterhostid[($userselection - 1)]
            if ( ($vmtype -eq "vmware") -and (!($transport)) )
            {
                $vcgrab = Get-AGMHost -filtervalue id=$vcenterid 
                $transport = $vcgrab.transport
            }
        }
        
        # now we check the log date
        if ($endpit)
        {
            Clear-Host
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


        if (!($dbname))
        {
            Clear-Host
            While ($true) 
            {
                $dbname = Read-Host "Target Database SID"
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
        if (!($username))
        {
            Clear-Host
            While ($true) 
            {
                $username = Read-Host "User Name"
                if ($username -eq "")
                {
                    Write-Host -Object "The User Name cannot be blank"
                } 
                else
                {
                    break
                }
            }
        }
        if (!($orahome))
        {
            Clear-Host
            While ($true) 
            {
                $orahome = Read-Host "Oracle Home Directory"
                if ($orahome -eq "")
                {
                    Write-Host -Object "The Oracle Home Directory cannot be blank"
                } 
                else
                {
                    break
                }
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
        # switch section
        Clear-Host
        Write-Host "Do you want to set any Advanced Options?"
        Write-Host "1`: Proceed without setting any Options(default)"
        Write-Host "2`: I want to see/set all the options"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq 2) 
        { 
            $passwordenc = Read-Host -AsSecureString "Password"
            if ($passwordenc.length -ne 0)
            {
                $UnsecurePassword = ConvertFrom-SecureString -SecureString $passwordenc -AsPlainText
                $base64password = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UnsecurePassword))
            }
            [string]$tnsadmindir = Read-Host "TNS ADMIN DIRECTORY PATH" 
            [int]$totalmemory = Read-Host "DATABASE MEMORY SIZE IN MB" 
            [int]$sgapct = Read-Host "SGA %" 
            [int]$redosize = Read-Host "REDO SIZE" 
            [int]$shared_pool_size = Read-Host "SHARED_POOL_SIZE IN MB" 
            [int]$db_cache_size = Read-Host "DB_CACHE_SIZE IN MB" 
            [int]$db_recovery_file_dest_size = Read-Host "DB_RECOVERY_FILE_DEST_SIZE IN MB" 
            [int]$inmemory_size = Read-Host "INMEMORY_SIZE IN MB FOR VERSION 12C OR HIGHER" 
            [string]$diagnostic_dest = Read-Host "DIAGNOSTIC_DEST" 
            [int]$processes = Read-Host "MAX NUMBER OF PROCESSES" 
            [int]$open_cursors = Read-Host "MAX NUMBER OF OPEN CURSORS" 
            [string]$tnsip = Read-Host "TNS LISTENER IP" 
            [int]$tnsport = Read-Host "TNS LISTENER PORT" 
            [string]$tnsdomain = Read-Host "TNS DOMAIN NAME" 
            [string]$pdbprefix = Read-Host "PDB PREFIX" 

            Write-Host "1`: CHANGE DATABASE DBID(default)"
            Write-Host "2`: DO NOT CHANGE DATABASE DBID"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $userselection = 1 }
            if ($userselection -eq 1) {  $nonid = $FALSE  }
            if ($userselection -eq 2) {  $nonid = $TRUE  }
            Write-Host "1`: ARCHIVE MODE(default)"
            Write-Host "2`: NO ARCHIVE MODE"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $userselection = 1 }
            if ($userselection -eq 1) {  $noarchivemode = $FALSE  }
            if ($userselection -eq 2) {  $noarchivemode = $TRUE  }
            Write-Host "1`: DO NOT CLEAR ARCHIVELOG(default)"
            Write-Host "2`: CLEAR ARCHIVELOG"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $userselection = 1 }
            if ($userselection -eq 1) {  $nooratabupdate = $FALSE  }
            if ($userselection -eq 2) {  $nooratabupdate = $TRUE  }
            Write-Host "1`: UPDATE TNSNAMES.ORA(default)"
            Write-Host "2`: DO NOT UPDATE TNSNAMES.ORA"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $userselection = 1 }
            if ($userselection -eq 1) {  $notnsupdate = $FALSE  }
            if ($userselection -eq 2) {  $notnsupdate = $TRUE  }
            Write-Host "1`: DO NOT CLEAR OS_AUTHENT_PREFIX(default)"
            Write-Host "2`: CLEAR OS_AUTHENT_PREFIX"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $userselection = 1 }
            if ($userselection -eq 1) {  $CLEAR_OS_AUTHENT_PREFIX = $FALSE  }
            if ($userselection -eq 2) {  $CLEAR_OS_AUTHENT_PREFIX = $TRUE  }           
            Write-Host "1`: RESTORE WITH RECOVERY(default)"
            Write-Host "2`: DONT OPEN DB"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $userselection = 1 }
            if ($userselection -eq 1) {  $norrecovery = $FALSE  }
            if ($userselection -eq 2) {  $norrecovery = $TRUE  }      
            Write-Host "1`: DO NOT USE EXISTING ORACLE PASSWORD FILE(default)"
            Write-Host "2`: USE EXISTING ORACLE PASSWORD FILE"
            Write-Host ""
            [int]$userselection = Read-Host "Please select from this list (1-2)"
            if ($userselection -eq "") { $userselection = 1 }
            if ($userselection -eq 1) {  $useexistingorapw = $FALSE  }
            if ($userselection -eq 2) {  $useexistingorapw = $TRUE  }
         }
        else 
        {
            $norrecovery = $FALSE
        }   
        
        
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
       



        # we are done
        Clear-Host  
        Write-Host "Guided selection is complete.  The values entered would result in the following command:"
        Write-Host ""
        if ($dbname)
        {   
            if ($recoverypoint)
            {
                Write-Host -nonewline "New-AGMLibOracleMount -appid $appid -mountapplianceid $mountapplianceid -appname $appname -imageid $imageid -label `"$label`" -targethostid $targethostid -dbname `"$dbname`" -username `"$username`" -orahome `"$orahome`"  -recoverypoint `"$recoverypoint`""
                if ($mountmode)
                {
                    Write-Host -nonewline " -mountmode $mountmode -mapdiskstoallesxhosts $mapdiskstoallesxhosts"
                }
            }
            else 
            {
                Write-Host -nonewline "New-AGMLibOracleMount -appid $appid -mountapplianceid $mountapplianceid -appname $appname -imageid $imageid -label `"$label`" -targethostid $targethostid -dbname `"$dbname`" -username `"$username`" -orahome `"$orahome`""
                if ($sltid)
                {
                    Write-Host -nonewline " -sltid $sltid -slpid $slpid"
                }
                if ($mountmode)
                {
                    Write-Host -nonewline " -mountmode $mountmode -mapdiskstoallesxhosts $mapdiskstoallesxhosts"
                }
            }
            if ($nonid) {Write-Host -nonewline " -nonid"}
            if ($noarchivemode) {Write-Host -nonewline " -noarchivemode"}
            if ($clearlog) {Write-Host -nonewline " -clearlog"}
            if ($notnsupdate) {Write-Host -nonewline " -notnsupdate"}
            if ($nooratabupdate) {Write-Host -nonewline " -nooratabupdate"}
            if ($CLEAR_OS_AUTHENT_PREFIX) {Write-Host -nonewline " -CLEAR_OS_AUTHENT_PREFIX"}
            if ($norrecovery) {Write-Host -nonewline " -norrecovery"}
            if ($useexistingorapw) {Write-Host -nonewline " -useexistingorapw"}
            if ($base64password) {Write-Host -nonewline " -base64password `"$base64password`""}
            if ($tnsadmindir) {Write-Host -nonewline " -tnsadmindir `"$tnsadmindir`""}
            if ($totalmemory) {Write-Host -nonewline " -totalmemory $totalmemory"}
            if ($sgapct) {Write-Host -nonewline " -sgapct $sgapct"}
            if ($redosize) {Write-Host -nonewline " -redosize $redosize"}
            if ($shared_pool_size) {Write-Host -nonewline " -shared_pool_size $shared_pool_size"}
            if ($db_cache_size) {Write-Host -nonewline " -db_cache_size $db_cache_size"}
            if ($db_recovery_file_dest_size) {Write-Host -nonewline " -db_recovery_file_dest_size $db_recovery_file_dest_size"}
            if ($inmemory_size) {Write-Host -nonewline " -inmemory_size $inmemory_size"}
            if ($diagnostic_dest) {Write-Host -nonewline " -diagnostic_dest `"$diagnostic_dest`""}
            if ($processes) {Write-Host -nonewline " -processes $processes"}
            if ($open_cursors) {Write-Host -nonewline " -open_cursors $open_cursors"}
            if ($tnsip) {Write-Host -nonewline " -tnsip `"$tnsip`""}
            if ($tnsport) {Write-Host -nonewline " -tnsport $tnsport"}
            if ($tnsdomain) {Write-Host -nonewline " -tnsdomain `"$tnsdomain`""}
            if ($pdbprefix) {Write-Host -nonewline " -pdbprefix `"$pdbprefix`""}

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

    #handle unsecure password (why oh why)
    if ($password)
    {
        $Bytes = [System.Text.Encoding]::Unicode.GetBytes($password)
        $base64password =[Convert]::ToBase64String($Bytes)
    }
    

    if (($appid) -and ($mountapplianceid) -and (!($imageid)))
    {
        # if we are not running guided mode but we have an appid without imageid, then lets get the latest image on the mountappliance ID
        $imagegrab = Get-AGMImage -filtervalue "appid=$appid&targetuds=$mountapplianceid&jobclass=snapshot&jobclass=StreamSnap&jobclass=dedupasync&jobclass=OnVault" -sort "consistencydate:desc,jobclasscode:asc" -limit 1
        if ($imagegrab.count -eq 1)
        {   
            $imageid = $imagegrab.id
            $imagename = $imagegrab.backupname
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch a snapshot, dedupasync, StreamSnap or OnVault Image for appid $appid on appliance with clusterID $mountapplianceid"
            return
        }
    }

    if (!($appname))
    {
        $appname = (Get-AGMImage -id $imageid).appname
    }

    # recovery point handling
    if ($recoverypoint)
    {
        $recoverytime = Convert-ToUnixDate $recoverypoint
    }

    # recovery or not
    if (!($recoverdb))
    { 
        $recoverdb = "true" 
    }
   
    if (!($label))
    {
        $label = ""
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

    if ($targethostid -eq "")
    {
        Get-AGMErrorMessage -messagetoprint "Cannot proceed without a targethostid or targethostname"
        return
    }
    
    
    if ($dbname) 
    {
        # the defaults we have to have
        $body = [ordered]@{}
        $body += @{ host = @{ id = $targethostid }}
        $body += @{ selectedobjects = @( @{ restorableobject = $appname })}
        if ($recoverytime) {  $body += @{ recoverytime = [string]$recoverytime }  }
        $body += @{ appaware = "true" }
        $provisioningoptions = @()
        $provisioningoptions += @( @{ name = 'databasesid'; value = $dbname } )
        $provisioningoptions += @( @{ name = 'username'; value = $username } )
        $provisioningoptions += @( @{ name = 'orahome'; value = $orahome } )
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
        # all the switches 
        if ($nonid) { $provisioningoptions += @( @{ name = 'nonid'; value = "true" } ) } else { $provisioningoptions += @( @{ name = 'nonid'; value = "false" } ) }
        if ($noarchivemode) { $provisioningoptions += @( @{ name = 'noarchivemode'; value = "true" } ) } else { $provisioningoptions += @( @{ name = 'noarchivemode'; value = "false" } ) }
        if ($clearlog) { $provisioningoptions += @( @{ name = 'clearlog'; value = "true" } ) } else { $provisioningoptions += @( @{ name = 'clearlog'; value = "false" } ) }
        if ($notnsupdate) { $provisioningoptions += @( @{ name = 'notnsupdate'; value = "true" } ) } else { $provisioningoptions += @( @{ name = 'notnsupdate'; value = "false" } ) }
        if ($CLEAR_OS_AUTHENT_PREFIX) { $provisioningoptions += @( @{ name = 'CLEAR_OS_AUTHENT_PREFIX'; value = "true" } ) } else { $provisioningoptions += @( @{ name = 'CLEAR_OS_AUTHENT_PREFIX'; value = "false" } ) }
        if ($norrecovery) { $provisioningoptions += @( @{ name = 'rrecovery'; value = "false" } ) } else { $provisioningoptions += @( @{ name = 'rrecovery'; value = "true" } ) }
        if ($useexistingorapw) { $provisioningoptions += @( @{ name = 'useexistingorapw'; value = "true" } ) } else { $provisioningoptions += @( @{ name = 'useexistingorapw'; value = "false" } ) }
        # all the options
        if ($password) { $provisioningoptions += @( @{ name = 'password'; value = $base64password } ) } 
        if ($tnsadmindir) { $provisioningoptions += @( @{ name = 'tnsadmindir'; value = $tnsadmindir } ) } 
        if ($sgapct) { $provisioningoptions += @( @{ name = 'sgapct'; value = $sgapct } ) } 
        if ($redosize) { $provisioningoptions += @( @{ name = 'redosize'; value = $redosize } ) } 
        if ($shared_pool_size) { $provisioningoptions += @( @{ name = 'shared_pool_size'; value = $shared_pool_size } ) } 
        if ($db_cache_size) { $provisioningoptions += @( @{ name = 'db_cache_size'; value = $db_cache_size } ) } 
        if ($db_recovery_file_dest_size) { $provisioningoptions += @( @{ name = 'db_recovery_file_dest_size'; value = $db_recovery_file_dest_size } ) } 
        if ($inmemory_size) { $provisioningoptions += @( @{ name = 'inmemory_size'; value = $inmemory_size } ) } 
        if ($diagnostic_dest) { $provisioningoptions += @( @{ name = 'diagnostic_dest'; value = $diagnostic_dest } ) } 
        if ($processes) { $provisioningoptions += @( @{ name = 'processes'; value = $processes } ) } 
        if ($open_cursors) { $provisioningoptions += @( @{ name = 'open_cursors'; value = $open_cursors } ) } 
        if ($tnsip) { $provisioningoptions += @( @{ name = 'tnsip'; value = $tnsip } ) } 
        if ($tnsport) { $provisioningoptions += @( @{ name = 'tnsport'; value = $tnsport } ) } 
        if ($tnsdomain) { $provisioningoptions += @( @{ name = 'tnsdomain'; value = $tnsdomain } ) } 
        if ($pdbprefix) { $provisioningoptions += @( @{ name = 'pdbprefix'; value = $pdbprefix } ) } 


        $body += @{ provisioningoptions = $provisioningoptions }

        if ($mountmode) {  $body += @{ physicalrdm = [string]$physicalrdm }  }
        if ($mountmode) {  $body += @{ rdmmode = [string]$rdmmode }  }
        if ($restoreoptions) {  $body += @{ restoreoptions = $restoreoptions }  }

    }
    else 
    {
        $hostobject = New-Object -TypeName psobject
        $hostobject | Add-Member -MemberType NoteProperty -Name id -Value $targethostid
        $body = New-Object -TypeName psobject
        $body | Add-Member -MemberType NoteProperty -name label -Value $label
        $body | Add-Member -MemberType NoteProperty -name image -Value $imagename
        $body | Add-Member -MemberType NoteProperty -name host -Value $hostobject
    }

    $json = $body | ConvertTo-Json

    if ($monitor)
    {
        $wait = $true
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
        $i=0
        while ($i -lt 8)
        {
            Clear-Host
            write-host "Checking for a running job for appid $appid against targethostname $targethostname"
            $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=False&targethost=$targethostname" -sort queuedate:desc -limit 1 
            if (!($jobgrab.jobname))
            {
                write-host "Job not running yet, will wait 15 seconds and check again"
                Start-Sleep -s 15
                $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=False&targethost=$targethostname" -sort queuedate:desc -limit 1 
                if (!($jobgrab.jobname))
                {
                    $1++
                }
            }
            else
            {   
                $i=8
                $jobgrab| select-object jobname,status,progress,queuedate,startdate,targethost
                
            }
        }
        if (($jobgrab.jobname) -and ($monitor))
        {
            Get-AGMLibFollowJobStatus $jobgrab.jobname
        }
    }
}
