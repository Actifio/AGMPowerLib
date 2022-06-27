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


Function ([string]$diskpoolid,[string]$applianceid,[string]$appid,[switch][alias("f")]$forget,[switch][alias("m")]$monitor,[switch][alias("o")]$ownershiptakeover) 
{
    <#
    .SYNOPSIS
    Imports or forgets OnVault images
    There is no Forget-AGMOnVault command.   You perform both import and forget from this function. 

    .EXAMPLE
    Import-AGMLibOnvault -diskpoolid 20060633 -applianceid 1415019931 

    Imports all OnVault images from disk pool ID 20060633 onto Appliance ID 1415019931

    .EXAMPLE
    Import-AGMLibOnVault -diskpoolid 20060633 -applianceid 1415019931 -appid 4788
    
    Imports all OnVault images from disk pool ID 20060633 and App ID 4788 onto Appliance ID 1415019931

    .EXAMPLE
    Import-AGMLibOnVault -diskpoolid 20060633 -applianceid 1415019931 -appid 4788 -owner
    
    Imports all OnVault images from disk pool ID 20060633 and App ID 4788 onto Appliance ID 1415019931 and takes ownership

    .EXAMPLE
    Import-AGMLibOnVault -diskpoolid 20060633 -applianceid 1415019931 -appid 4788 -forget
    
    Forgets all OnVault images imported from disk pool ID 20060633 and App ID 4788 onto Appliance ID 1415019931

    .DESCRIPTION
    A function to import OnVault images

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

    if ((!($diskpoolid)) -or (!($applianceid)))
    {

        write-host ""
        Write-Host "This function is used to import OnVault images into an Appliance."
        Write-host "We need to determine which pool to import from and which appliance created the images to import"
        Write-host "If importing we also need to decide whether the importing appliance (which owns the selected pool) should take ownership of the imported images"
        Write-host "Alternatively we can decide to have the appliance forget any previously imported images, rather than discover new ones"
        write-host "If you are having what look like timeout issues, please run connect-agm with a -agmtimeout value larger than then the default of 60 seconds"
        Write-host ""

        $diskpoolgrab = Get-AGMDiskPool -filtervalue pooltype=vault | Sort-Object name
        if ($diskpoolgrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any disk pools to list"
            return
        }
        if ($diskpoolgrab.count -eq 1)
        {
            $diskpoolid = $diskpoolgrab.id
            write-host "Only one OnVault diskpool was found.  We will use this one:"  $diskpoolgrab.name 
        }
        else
        {
            write-host "Pool selection menu - which Diskpool we will use (which also determines which Appliance we use)"
            Write-host ""
            $i = 1
            foreach ($pool in $diskpoolgrab)
            { 
                Write-Host -Object "$i`: $($pool.name) (ID: $($pool.id)) on $($pool.cluster.name)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $diskpoolgrab.name.count
                [int]$poolselection = Read-Host "Please select a Diskpool to import from (1-$listmax)"
                if ($poolselection -lt 1 -or $poolselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $diskpoolid =  $diskpoolgrab.id[($poolselection - 1)]
        }
        

        write-host "Inspecting the disk pool for source appliances"
        write-host ""
        $appliancegrab = Get-AGMAPIData  -endpoint /diskpool/$diskpoolid/vaultclusters
        if ($appliancegrab.cluster.clusterid.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any appliances to list"
            return
        }
        if ($appliancegrab.cluster.clusterid.count -eq 1)
        {
            $applianceid = $appliancegrab.cluster.clusterid
            $appliancename = $appliancegrab.cluster.name
            write-host "Only one Appliance was found.  We will use this one: $appliancename (ID: $applianceid)"
        }
        else
        {
            write-host "Appliance selection menu - which Appliance will we import from (this is the Appliance that made the images)"
            Write-host ""
            $i = 1
            foreach ($appliance in $appliancegrab.cluster)
            { 
                Write-Host -Object "$i`: $($appliance.name) (ID: $($appliance.clusterid))"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $appliancegrab.cluster.name.count
                [int]$appselection = Read-Host "Please select an Appliance to import into (1-$listmax)"
                if ($appselection -lt 1 -or $appselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $applianceid =  $appliancegrab.cluster.clusterid[($appselection - 1)]
            $appliancename =  $appliancegrab.cluster.name[($appselection - 1)]
        }
        Write-Host ""
        write-host "Inspecting the disk pool for source applications created by source Appliance $appliancename"
        $applicationgrab = Get-AGMAPIData -endpoint /diskpool/$diskpoolid/vaultclusters/$applianceid 
        if ($applicationgrab.host)
        {
            $printarray = @()
            foreach ($app in $applicationgrab)
            {       
                $printarray += [pscustomobject]@{
                hostname = $app.host.hostname
                appname = $app.application.appname
                backupcount = $app.backupcount
                }
            }
        }
        else {
            Get-AGMErrorMessage -messagetoprint "Failed to find any application images to list"
            return
        }
        write-host "Found the following images."
        $printarray | sort-object hostname,appname | Format-Table

        Write-Host ""
        Write-Host "Do you want to import these images?"
        Write-Host ""
        Write-Host "1`: Yes I want to import them (default)"
        Write-Host "2`: Exit (this is not the disk pool I was looking for)"
        $ownerchoice = Read-Host "Please select from this list (1-2)"
        if ($ownerchoice -eq 2) { return }
        Write-Host ""
        Write-Host "Do you want to have the selected appliance take ownership of any images. "
        Write-Host ""
        Write-Host "1`: Don't take ownership (default)"
        Write-Host "2`: Take ownership of any imported images"
        write-host "3`: Forget any imported images (rather than importing new ones)"

        $ownerchoice = Read-Host "Please select from this list (1-3)"
        if ($ownerchoice -eq 2) { $owner = $true}
        if ($ownerchoice -eq 3) { $forget = $true}

        Write-Host ""
        Write-Host "Do you want to monitor the import to completion. "
        Write-Host ""
        Write-Host "1`: Monitor the import (default)"
        Write-Host "2`: Dont monitor the import"
        $ownerchoice = Read-Host "Please select from this list (1-2)"
        if ($ownerchoice -eq 1 -or $ownerchoice -eq "") { $monitor = $true}
    
        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline "Import-AGMLibOnvault -diskpoolid $diskpoolid -applianceid $applianceid"  
        if ($forget) { Write-Host -nonewline " -forget" }
        if ($owner) { Write-Host -nonewline " -owner" }
        if ($monitor) { Write-Host -nonewline " -monitor" }
        if ($appid) { Write-Host -nonewline " -appid $appid" }
        Write-Host ""
        Write-Host "1`: Run the command now.  This command will run in the background unless you selected monitor option. (default)"
        Write-Host "2`: Exit without running the command"
        $appuserchoice = Read-Host "Please select from this list (1-2)"
        if ($appuserchoice -eq 2)
        {
            return
        }
    }

    if ($monitor)
    {
        if ($appid)
        {
            $startcount = Get-AGMImageCount -filtervalue "jobclass=OnVault&sourceuds=$applianceid&appid=$appid&poolid=$diskpoolid"
        }
        else
        {
            $startcount = Get-AGMImageCount -filtervalue "jobclass=OnVault&sourceuds=$applianceid&poolid=$diskpoolid"
        }
    }

    if ($appid)
    {
        if ($owner)
        {
            $import = Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -appid $appid -owner
        }
        elseif ($forget)
        {
            $import = Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -appid $appid -forget
        }
        else 
        {
            $import = Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -appid $appid 
        }
    }
    else {
        if ($owner)
        {
            $import = Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -owner
        }
        elseif ($forget)
        {
            $import = Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid -forget
        }
        else 
        {
            $import = Import-AGMOnvault -diskpoolid $diskpoolid -applianceid $applianceid  
        }
    }

    $importid = $import.id
    if ($monitor -and (!($importid)))
    {
        $import
    }
    elseif ($monitor -and $importid)
    {
        Write-host "Image count before import:  $startcount"
        $done = 0
        do 
        {
            $jobgrab = Get-AGMAPIData -endpoint /diskpool/vaultclusters/$importid
            if ($jobgrab.errormessage)
            {   
                $done = 1
                $jobgrab
            }    
            elseif (!($jobgrab.status)) 
            {
                Get-AGMErrorMessage -messagetoprint "Failed to find import with ID $importid"
                $done = 1
            }
            elseif ($jobgrab.status -like "pending")
            {
                write-host "Import status: pending"
                Start-Sleep -s 5
            }
            else 
            {
                $status = $jobgrab.status
                write-host "Import status: $status"
                $done = 1    
            }
        } until ($done -eq 1)
        if ($appid)
        {
            Start-Sleep -seconds 10
            $endcount = Get-AGMImageCount -filtervalue "jobclass=OnVault&sourceuds=$applianceid&appid=$appid&poolid=$diskpoolid"
        }
        else
        {
            Start-Sleep -seconds 10
            $endcount = Get-AGMImageCount -filtervalue "jobclass=OnVault&sourceuds=$applianceid&poolid=$diskpoolid"
        }
        Write-host "Image count after import:  $endcount"
    }
    else {

        $import
    }
}