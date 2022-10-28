
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

Function New-AGMLibMultiMount ([string]$csvfile,[array]$imagelist,[array]$hostlist,[string]$hostid,[string]$mountpoint,[switch][alias("a")]$appnamesuffix, [switch][alias("h")]$hostnamesuffix,[switch][alias("c")]$condatesuffix,[switch][alias("i")]$imagesuffix,[string]$label,[int]$startindex) 
{
    <#
    .SYNOPSIS
    Mounts a number of FileSystems to a group of hosts

    .EXAMPLE
    New-AGMLibMultiMount -imagelist $imagelist -hostlist $hostlist -mountpoint /tmp/imagecheck

    This command likes to use the output of Get-AGMLibImageRange as $imagelist
    So we could create a list like this:
    $imagelist = Get-AGMLibImageRange -fuzzyappname demo-sql -olderlimit 3

    We could get a list of hosts to mount to with a command like this:
    $hostlist = Get-AGMHost -filtervalue "hostname~scanhost*" | select id,hostname

    The logic to handle mount points is simple.
    The user must supply a starter mount point with a trailing slash.
    For linux hosts this would be:    -mountpoint /tmp/testmount/
    For Windows hosts this would be:  -mountpoint C:\temp\

    The suffix is optional but recommended.  This basically adds an extra foldername to the mount point.

    There are four mechanisms to get unique mount names:
    1)  You can specify -h and the Host Name will be used as part of the mount point
    2)  You can specify -a and the App Name will be used as part of the mount point
    3)  You can specify -i and the Image Name will be used as part of the mount point
    4)  You can specify -c and the Consistency Date will be used as part of the mountpoint
   
    The point point will always end in a unique number to guarantee uniqueness.
    If you want to control the starting number of that number use -startindex

    By default it will use a label of "MultiFS Recovery" to make the mounts easier to find.  you can changes this with -label xxxx  to set your own unique label.

    .EXAMPLE
    New-AGMLibMultiMount -imagelist $imagelist -hostid $hostid  -mountpoint "/tmp/testmount/"
    
    If you only have a single  host you can specify it singly using -hostid
    All your mounts will go to that single Host 

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

    # handle hostlist vs hostid
    if ($hostlist.id)
    {
        $hostlist = ($hostlist).id 
    }
    if ( (!($hostlist)) -and ($hostid) )
    {
        $hostlist = $hostid
    }

    # guided menu
    if ((!($mountpoint)) -and (!($imagelist)) -and (!($csvfile)))
    {
        Write-host "This function is used to start a large number of file system mounts in a single command.  This is done by supplying:"
        Write-host "-- A list of images to mount, normally created with New-AGMLibImageRange and then placed into a CSV file"
        Write-Host "-- A host list or a host ID which will be our scanning hosts that we use to check our images" 
        Write-host "-- A mount point with parameters"
        Write-host ""
        write-host "The end result will be that we will mount all the listed images on our scanning hosts so they can be checked"
        write-host ""
        Write-host "We first require an imagelist file in CSV format. This needs to be created with Get-AGMLibImageRange and exported to a CSV file."
        Write-host "If you have not created it, then choose Exit, run that command first and work with the output and then come back here when done"
        Write-host ""
        Write-Host "1`: I have the image list as a file"
        Write-Host "2`: I need to run Get-AGMLibImageRange to create the CSV file"
        Write-Host "3`: Exit"
        While ($true) 
        {
            Write-host ""
            $userchoice1 = Read-Host "Please select from this list (1-3)"
            if ($userchoice1 -lt 1 -or $userchoice1 -gt 3)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-3]"
            } 
            else
            {
                break
            }
        }
        if ($userchoice1 -eq 3) { return }
        if ($userchoice1 -eq 1)
        {
            [string]$filename = Read-Host "Supply the file name in CSV format"
            if ( Test-Path $filename )
            {
                $imagelist = Import-Csv -Path $filename
                if (!($imagelist.backupname))
                {
                    Get-AGMErrorMessage -messagetoprint "The file named $filename does not contain an backupname column and cannot be used.  Was it created with Get-AGMLibImageRange?"
                    return
                }
            }
            else
            {
                Get-AGMErrorMessage -messagetoprint "The file named $filename could not be found."
                return;
            }
        }
        if ($userchoice1 -eq 2)
        {
            Get-AGMLibImageRange
            
            return
        }
        
        # host ID list
        Clear-Host
        Write-Host "You now need to supply a list of host IDs to mount to.  These hosts need to have the same OS (either Linux or Win32)"
        Write-Host "Make sure the hosts are on the same appliance name as the images"
        Write-host ""
        Write-Host "1`: Show me the hosts and I will select them (default)"
        write-host "2`: I have the list already, let me supply it"
        Write-Host "3`: Exit"
        $userchoice2 = Read-Host "Please select from this list (1-3)"
        if ($userchoice2 -eq 3) { return }
        if ($userchoice2 -eq 2)
        {
            [string]$hostselection = Read-Host "Please enter all hosts using their ID, comma separated"
            $hostlist = @($hostselection)
        }
        else {   
            $appliancegrab = Get-AGMAppliance | select-object name,clusterid | sort-object name
            if ($appliancegrab.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Failed to find any appliances to work with"
                return
            }
            if ($appliancegrab.name.count -eq 1)
            {
                $mountapplianceid = $appliancegrab.clusterid
            }
            else
            {
                Clear-Host
                write-host "Appliance selection menu - which Appliance will run these mounts"
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
            }
    
            Clear-Host
            Write-Host "Are the scanning hosts Linux or Windows?"
            Write-host ""
            Write-Host "1`: Linux"
            Write-Host "2`: Windows"
            Write-Host "3`: Exit"
            $userchoice3 = Read-Host "Please select from this list (1-3)"
            if ($userchoice3 -eq "" -or $userchoice3 -eq 3)  { return }
            if ($userchoice3 -eq 1)
            {
                $ostype = "Linux"
                $hostgrab = Get-AGMHost -filtervalue "sourcecluster=$mountapplianceid&ostype=$ostype" -sort "name:asc"
            }
            if ($userchoice3 -eq 2)
            {
                $ostype = "Win32"
                $hostgrab = Get-AGMHost -filtervalue "sourcecluster=$mountapplianceid&ostype=$ostype" -sort "name:asc"
            }
            if ($hostgrab.id.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "No hosts were found with selected ostype $ostype"
                return
            }

            Clear-Host
            Write-Host "Target host selection menu"
            $hostgrab  | Select-Object id,hostname,ostype,@{N='appliancename'; E={$_.appliance.name}} | Format-Table
            write-host ""
            [string]$hostselection = Read-Host "Please select all hosts using their ID, comma separated"
            $hostlist = @($hostselection)
        }
        # mount point
        Clear-Host
        While ($true)  { if ($fieldsep.length -eq 0) {  
            if ($ostype -eq "Linux")
            {
                [string]$mountpoint = Read-Host "You now need to supply a mount point such as /tmp/testmount/   making sure to add the trailing slash as shown" 
                if ($mountpoint -match '/$') { $fieldsep = "/" }
            }
            if ($ostype -eq "Win32")
            {
                [string]$mountpoint = Read-Host "You now need to supply a mount point such as  C:\Temp\  making sure to add the trailing slash as shown" 
                if ($mountpoint -match '\\$') { $fieldsep = "\" }
            }
        } else { break } }
        # labels
        Clear-Host
        write-host "Labels are used to help find the images later, if you hit enter without typing anything, the label will default to: MultiFS Recovery"
        write-host ""
        $labelgrab = Read-host "Enter a Label if you want to use something different to `'MultiFS Recovery`'"
        if (!($labelgrab))
        {
            $label = "MultiFS Recovery"
        }
        else {
            $label = $labelgrab
        }
        Clear-Host
        Write-host "Finally we need to choose which suffixes we will use in the mount points to both guarantee uniqueness and make the images easy to find"
        Write-host " There are four mechanisms to get unique mount names."
        Write-host " 1)  You can specify -h and the Host Name will be used as part of the mount point"
        Write-host " 2)  You can specify -a and the App Name will be used as part of the mount point"
        Write-host " 3)  You can specify -i and the Image Name will be used as part of the mount point"
        Write-host " 4)  You can specify -c and the Consistency Date will be used as part of the mountpoint"
        write-host
        $hostoptiongrab = Read-Host "Do you want to use the host name as part of the mount point (y/Y)"
        if ($hostoptiongrab -eq "y" -or $hostoptiongrab -eq "Y ") 
        { 
            $hostnamesuffix = $true 
            $suffixoptions = " -hostnamesuffix"
        }
        $appoptiongrab = Read-Host "Do you want to use the app name as part of the mount point (y/Y)"
        if ($appoptiongrab -eq "y" -or $appoptiongrab -eq "Y ") 
        { 
            $appnamesuffix = $true 
            $suffixoptions = $suffixoptions +" -appnamesuffix"
        }
        $imageoptiongrab = Read-Host "Do you want to use image name as part of the mount point (y/Y)"
        if ($imageoptiongrab -eq "y" -or $imageoptiongrab -eq "Y ") 
        { 
            $imagesuffix = $true 
            $suffixoptions = $suffixoptions +" -imagesuffix"
        }
        $condateoptiongrab = Read-Host "Do you want to use consistency date as part of the mount point (y/Y)"
        if ($condateoptiongrab -eq "y" -or $condateoptiongrab -eq "Y ") 
        { 
            $condatesuffix = $true 
            $suffixoptions = $suffixoptions +" -condatesuffix"
        }
        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host "New-AGMLibMultiMount -csvfile `"$filename`" -mountpoint `"$mountpoint`" -hostlist `"$hostselection`" -label `"$label`" $suffixoptions"  
        Write-Host ""
        Write-Host "1`: Run the command now (default)"
        Write-Host "2`: Exit without running the command"
        $appuserchoice = Read-Host "Please select from this list (1-2)"
        if ($appuserchoice -eq 2)
        {
            return
        }
    }


    if (!($mountpoint))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a starter mountpoint such as /tmp/testmount/ or C:\Temp\"
        return
    }

    if ($mountpoint -match '\\$')
    { $fieldsep = "\" }
    if ($mountpoint -match '/$')
    { $fieldsep = "/" }
    
    if (!($fieldsep))
    {
        Get-AGMErrorMessage -messagetoprint "Last character of $mountpoint needs to be forward slash for Linux such as /tmp/testmount/ or backslash for Windows such C:\Temp\"
        return
    }

    if ($csvfile)
    {
        if ( Test-Path $csvfile )
        {
            $imagelist = Import-Csv -Path $csvfile
            if (!($imagelist.backupname))
            {
                Get-AGMErrorMessage -messagetoprint "The file named $csvfile does not contain an backupname column and cannot be used.  Was it created with Get-AGMLibImageRange?"
                return
            }
        }
        else
        {
            Get-AGMErrorMessage -messagetoprint "The file named $csvfile could not be found."
            return
        }
    }


    if (!($imagelist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an imagelist"
        return
    }
    
    if (!($hostlist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an array of Host IDs using -hostlist or a single Host ID using -hostid"
        return
    }


    if (!($startindex))
    {
        $startindex = 1
    }

    if (!($label))
    {
        $label = "MultiFS Recovery"
    }

    $hostlist = $hostlist.Split(",")
    $hostcount = $hostlist.count
    $hostroundrobin = 0
    $lastappid = ""
    $lastcondate = ""

    # The user can specify the starting number or we will start at 1
    if (!($startindex))
    {
        $startindex = 1
    }
    

    foreach ($image in $imagelist)
    {
        # start the moint point
        $imagemountpoint = $mountpoint
        if (($lastappid -eq $image.appid) -and ($lastcondate -eq $image.consistencydate))
        {
            Write-Host "Not mounting AppName:" $image.appname "AppID:" $image.appid " Jobclass:" $image.jobclass " ImageName:" $image.backupname " ConsistencyDate:" $image.consistencydate "because the previous mount had the same appid and consistency date" 
        }
        else 
        {
            if ($hostnamesuffix)
            { 
                # for linux mount points starting with / we need to trim the leading / to avoid // in the mount point
                if ($image.hostname.Substring(0,1) -match "[/]")
                {
                    $image.hostname = $image.hostname.substring(1) 
                }
                # we also remove spaces in app names and full colon, so they dont make strange mount points
                $imagemountpoint = $imagemountpoint + $image.hostname -replace '\s','' -replace ':',''  
                $imagemountpoint = $imagemountpoint + $fieldsep
            }
            if ($appnamesuffix)
            { 
                # for linux mount points starting with / we need to trim the leading / to avoid // in the mount point
                if ($image.appname.Substring(0,1) -match "[/]")
                {
                    $image.appname = $image.appname.substring(1) 
                }
                # we also remove spaces in app names and full colon, so they dont make strange mount points
                $imagemountpoint = $imagemountpoint + $image.appname -replace '\s','' -replace ':',''  
                $imagemountpoint = $imagemountpoint + $fieldsep
            }
            if ($imagesuffix)
            { $imagemountpoint = $imagemountpoint + $image.backupname + $fieldsep }
            if ($condatesuffix)
            {  
                # we need to make the date just numbers
                $imagemountpoint = $imagemountpoint + $image.consistencydate -replace '\s','' -replace '-','' -replace ':',''  
                $imagemountpoint = $imagemountpoint + $fieldsep
            }

            # we always end on a number to guarantee uniqueness
            $imagemountpoint = $imagemountpoint + $startindex 
            $startindex += 1

            # we can now set the values needed for the mount
            $hostid = $hostlist[$hostroundrobin]
            $body = [ordered]@{
                label = "$label";
                image = $image.backupname;
                host = @{id=$hostid}
                migratevm = "false";
                restoreoptions = @(
                    @{
                        name = 'mountpointperimage'
                        value = "$imagemountpoint"
                    }
                )
            }
            $json = $body | ConvertTo-Json -depth 4
            Write-Host "    Mounting AppName:" $image.appname " AppID:" $image.appid " Jobclass:" $image.jobclass " ImageName:" $image.backupname " ConsistencyDate:" $image.consistencydate "to Host ID" $hostid "with mount point" $imagemountpoint           
            $imageid = $image.id
            Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json
            $hostroundrobin += 1
            if ($hostroundrobin -eq $hostcount )
            {
                $hostroundrobin = 0
            }
            $lastappid = $image.appid
            $lastcondate = $image.consistencydate
        }
    }
}