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


Function Restore-AGMLibMount ([string]$imageid,[string]$imagename,[string]$appname,[string]$appid,[string]$username,[string]$password,[string]$mountmode,[string]$recoverdb,[string]$recoverypoint,[string]$disableschedule,[string]$markdependent,[switch][alias("g")]$guided) 
{
    <#
    .SYNOPSIS
    Rewinds a mounted image to a previous point in time

    .EXAMPLE
    Rewind-AGMLibMount -g

    Runs a guided menu

    .EXAMPLE
    Restore-AGMLibMount -imageid 6384106 -username "oracle" -recoverypoint "2020-09-03 17:02"

    Rewinds an Oracle Database with image ID 6384106 to the specified recovery point.

    .EXAMPLE
    Restore-AGMLibMount -appid 6384030 -username "oracle"

    Rewinds an Oracle Database with image ID 6384106 to the specified recovery point.

    .DESCRIPTION
    A function to rewind a mount to a previous point in time

    There are two way to determine which image is used.  Specify the appname or appid:
    appid - if specified without an imageID or imagename then the most recent snapshot will be used
    appname - if specified without an imageID or imagename then the most recent snapshot will be used

    Otherwise specify a specific image by name or ID:
    imageid - if specified this image ID will be used to rewind the mounted database
    imagename - if specified this image name will be used to rewind the mounted database
    
    There are many options:
    username:  mandatory for Oracle, optional for SQL
    password:  needs to be base64 encoded
    mountmode:  vrdm, prdm or nfs   (VMware only)
    recoverdb:  whether to restore with recovery and start the DB, default is true, options are true or false
    recoverypoint:   if the image has an END pit, specify a date in ISO format like 2020-09-01 19:01:00
    disableschedule:   by fault this is true.   Can specify true or false
    markdependent:  VMware only,  can be true or false.  Default is false

    #>

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


    # if the user gave us nothing to start work, then ask for a mounted app name
    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $true
        Clear-Host
        Write-host "App selection menu"
        Write-host ""  
        $activeimagegrab1 = Get-AGMImage -filtervalue characteristic=1 | select-object childapp 
        $activeimagegrab = $activeimagegrab1.childapp | sort-object friendlytype,appname
        if ($activeimagegrab.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "There are no Active Images with child apps to list"
            return
        }
        if ($activeimagegrab.id.count -eq 1)
        {
            $appname =  $activeimagegrab.appname
            $appid = $activeimagegrab.id
            $hostid = $activeimagegrab.host.id
            $apptype = $activeimagegrab.friendlytype
            write-host "Found only one Child app $appname ($apptype) with App ID $appid when checking for Mounted Apps to rewind"
            write-host ""
        }
        else 
        {
            $i = 1
            foreach ($child in $activeimagegrab)
            { 
                if ($child.appname)
                {
                    $appname = $child.appname
                    $appid = $child.id
                    $apptype = $child.friendlytype
                    Write-Host -Object "$i`: $apptype - $appname ($appid)"
                    $i++
                }
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $activeimagegrab.appname.count
                [int]$appselection = Read-Host "Please select an app (1-$listmax)"
                if ($appselection -lt 1 -or $appselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $appname =  $activeimagegrab.appname[($appselection - 1)]
            $appid = $activeimagegrab.id[($appselection - 1)]
            $hostid = $activeimagegrab.host.id[($appselection - 1)]
        }
    }


    # if we got a appname lets check it right now
    if ( ($appname) -and (!($appid)) )
    {
        $appgrab = Get-AGMApplication -filtervalue "appname=$appname"
        if ($appgrab.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appname to a unique valid app.  Use: `"Get-AGMLibApplicationID $appname`"  and try again specifying the learned ID as -appid."
            return
        }
        else {
            $appid = $appgrab.id
            $frommount = $appgrab.frommount
        }
        if ($frommount -ne "True")
        {
            Get-AGMErrorMessage -messagetoprint "App $appname is not a child app.  This function is intended to rewind apps created by mounts where frommount equals True"
            return
        }
    }    

    if ( (!($appname)) -and ($appid) )
    {
        $appgrab = Get-AGMApplication -filtervalue "id=$appid"
        if ($appgrab.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appid to a unique valid app.  Use Get-AGMLibApplicationID to learn the appID nd try again"
            return
        }
        else {
            $appname = $appgrab.appname
            $frommount = $appgrab.frommount
        }
        if ($frommount -ne "True")
        {
            Get-AGMErrorMessage -messagetoprint "App $appname is not a child app.  This function is intended to rewind apps created by mounts where frommount equals True"
            return
        }
    }    



    

    # learn about the image if the user gave it
    if ($imagename)
    {
        $imagegrab = Get-AGMImage -filtervalue backupname=$imagename
        if ($imagegrab.id.count -eq 0)
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
            Write-Host ""
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
                    $endpit = $imagegrab.endpit
                    $appname = $imagegrab.appname
                    $appid = $imagegrab.application.id    
                }
            }
            else
            {
                $imagelist1 = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot"  | select-object -Property backupname,consistencydate,endpit,id | Sort-Object consistencydate
                if ($imagelist1.id.count -eq 0)
                {
                    Get-AGMErrorMessage -messagetoprint "Failed to fetch any snapshot Images for appid $appid"
                    return
                }
                $imagelist = $imagelist1  | select-object -Property backupname,consistencydate,endpit,id | Sort-Object consistencydate
                if ($imagelist1.count -eq 1)
                {
                    $imagegrab = Get-AGMImage -id $($imagelist).id
                    $imageid = $imagelist.id
                    $imagename = $imagegrab.backupname                
                    $consistencydate = $imagegrab.consistencydate
                    $endpit = $imagegrab.endpit  
                    write-host "Found only one snapshot of childapp $($appname):  ID $imageid   Imagename: $imagename   ConsistencyDate: $consistencydate" 
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
                    $endpit = $imagegrab.endpit
                }
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

        Write-host ""
        $username = read-host "Username"
        if ($username)
        {
            $passwordenc = Read-Host -AsSecureString "Password"
            if ($passwordenc.length -ne 0)
            {
                $UnsecurePassword = ConvertFrom-SecureString -SecureString $passwordenc -AsPlainText
                $password = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UnsecurePassword))
            }
        }

        
        $hostgrab = Get-AGMHost -id $hostid
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

            }
            if ($mountmode -eq "vrdm")
            {
                Write-Host "VMDK setting"
                Write-Host "1`: Don't mark dependent(default)"
                Write-Host "2`: Mark dependent"
                Write-Host ""
                [int]$userselection = Read-Host "Please select from this list (1-2)"
                if ($userselection -eq "") { $userselection = 1 }
                if ($userselection -eq 1) {  $markdependent = "false" }
                if ($userselection -eq 2) {  $markdependent = "true" }
            }
        }

        Write-Host "Recover database"
        Write-Host "1`: Recover database after restore(default)"
        Write-Host "2`: Don't recovery database after restore"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $recoverdb = "true"  }
        if ($userselection -eq 2) {  $recoverdb = "false"  } 

        Write-Host "1`: Disable Schedule (default)"
        Write-Host "2`: Leave Schedule enabled"
        Write-Host ""
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) { $notdisableschedule = "false" ; $disableschedule = "true" }
        if ($userselection -eq 2) { $notdisableschedule = "true" ; $disableschedule = "false"}  

        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline "Restore-AGMLibMount -imageid $imageid -appname `"$appname`" -appid $appid -recoverdb $recoverdb -disableschedule $disableschedule" 
        if ($markdependent) { Write-Host -nonewline " -markdependent $markdependent" }
        if ($username) { Write-Host -nonewline " -username `"$username`"" }
        if ($password) { Write-Host -nonewline " -password `"$password`"" }
        if ($recoverypoint) { Write-Host -nonewline " -recoverypoint `"$recoverypoint`"" }
        Write-Host ""
        Write-Host "1`: Run the command now"
        Write-Host "2`: Show the JSON used to run this command, but don't run it"
        Write-Host "3`: Exit without running the command (default)"
        $userchoice = Read-Host "Please select from this list (1-3)"
        if (!($userchoice)) { $userchoice = 3 }
        if ($userchoice -eq 2)
        {
            $jsonprint = "yes"
        }
        if ($userchoice -eq 3)
        {
            return
        }
    }

    if ($recoverypoint)
    {
        $recoverytime = Convert-ToUnixDate $recoverypoint
    }

    # recovery or not
    if (!($recoverdb))
    { 
        $recoverdb = "true" 
    }
    if ($disableschedule -eq "true")
    { 
        $notdisableschedule = "false" 
    }
    else
    {
        $notdisableschedule = "true" 
    }
    
    # learn about the image
    if ((!($imageid)) -and ($appid))
    {
        $imagegrab = Get-AGMLibLatestImage $appid
        if (!($imagegrab.backupname))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find snapshot for AppID using:  Get-AGMLibLatestImage $appid"
            return
        }   
        else {
            $imageid = $imagegrab.id
        }
    }


    if (!($imageid))
    {
        [string]$imageid = Read-Host "ImageID to restore"
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
            if ($markdependent -eq "true")
            {
                $rdmmode = "dependentvirtual"
            }
            else {
                $rdmmode = "independentvirtual"
            }
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

    $body = [ordered]@{
        recover = $recoverdb;
    }
    if ($recoverytime) {  $body += @{ recoverytime = [string]$recoverytime }  }
    if ($mountmode)
    {
        $body = $body + @{ physicalrdm = $physicalrdm }
        $body = $body + @{ rdmmode = $rdmmode }
    }
    if ($username)
    {
        $body = $body + @{ username = $username }
    }
    if ($password)
    {
        $body = $body + @{ password = $password }
    }
    $body = $body + @{ notdisableschedule = $notdisableschedule }


    $json = $body | ConvertTo-Json


    if ($jsonprint -eq "yes")
    {
        $compressedjson = $body | ConvertTo-Json -compress
        Write-host "This is the final command:"
        Write-host ""
        Write-host "Post-AGMAPIData  -endpoint /backup/$imageid/restore -body `'$compressedjson`'"
        return
    }

    Post-AGMAPIData  -endpoint /backup/$imageid/restore -body $json
}
