Function Get-AGMLibImageRange([string]$csvfile,[string]$appid,[string]$jobclass,[switch]$every,[string]$appname,[string]$clusterid,[string]$appliancename,[string]$apptype,[string]$fuzzyappname,[string]$sltname,[datetime]$consistencydate,[int]$newerlimit,[int]$olderlimit,[switch][alias("h")]$hours,[switch][alias("i")]$imported,[switch][alias("o")]$onvault) 
{
    <#
    .SYNOPSIS
    Displays the range of images for an application or applications

    .EXAMPLE
    Get-AGMLibImageRange
    You will be prompted to supply either application ID, Appname or fuzzyappname.   In addition or in place you can specify apptype
    If no newerlimit or olderlimit are specified then it defaults to -olderlimit 1 days
    If no consistencydate is specified todays date and time is assumed

    .EXAMPLE
    Get-AGMLibImageRange -appid 4771
    Get all snapshot created in the last day for appid 4771

    .EXAMPLE
    Get-AGMLibImageRange -appid 4771 -o
    Get all snapshot and OnVault images created in the last day for appid 4771
    Only unique OnVault images will be shown, meaning if a snapshot and an OnVault image have the same consistencydate only the snapshot will be shown
    
    .EXAMPLE
    Get-AGMLibImageRange -appname smalldb
    Get all snapshot created in the last day for any app with app name smalldb

    .EXAMPLE
    Get-AGMLibImageRange -fuzzyappname smalldb
    Get all snapshot created in the last day for any app with an app name like smalldb

    .EXAMPLE
    Get-AGMLibImageRange -sltname Gold
    Get all snapshot created in the last day for any image with an SLT name like Gold

    .EXAMPLE
    Get-AGMLibImageRange -appid 4771 -appliancename "sa-hq"
    Get all snapshot created in the last day for appid 4771 on the appliance called sa-hq

    .EXAMPLE
    Get-AGMLibImageRange -appid 4771 -clusterid 1415038912
    Get all snapshot created in the last day for appid 4771 on the appliance with the specified clusterid

    .EXAMPLE
    Get-AGMLibImageRange -appid 4771 -jobclass OnVault
    Get all OnVault created in the last day for appid 4771

    .EXAMPLE
    Get-AGMLibImageRange -appid 4771 -olderlimit 4 -hours
    Get all snapshots created in the last four hours for appid 4771

    .EXAMPLE
    Get-AGMLibImageRange -apptype VMBackup -olderlimit 2
    Get all snapshots created in the last two days for any VMBackup

    .EXAMPLE
    Get-AGMLibImageRange -appid 4771 -olderlimit 4 -newerlimit 4 -consistencydate "2020-08-04 12:00"
    Get all snapshots created up to four days before or 4 days afer the date specified for the app specified

    .EXAMPLE
    Get-AGMLibImageRange -appid 4771 -olderlimit 4 -newerlimit 2 
    Get all snapshots created between 4 days ago (from olderlimit) and 2 days ago (from newerlimit, being 2 days newer than olderlimit) for the app specified.  
    Note that if you make newerlimit greater than olderlimit you  will be looking into the future, meaning you will get all images created from 4 days ago until now.

    .DESCRIPTION
    A function to find a range of images available for an application

    Building your Imagelist:

    To get a list of applications, use:  Get-AGMApplication -sort "hostname:asc,appname:asc"| select id, @{N='hostname'; E={$_.host.hostname}}, appname, apptype, @{N='clustername'; E={$_.cluster.name}} | format-table
    To get a list of SLTNames or policynames, use:  Get-AGMLibPolicies

    First we build an object that contains a list of images. For this we can use Get-AGMLibImageRange in a syntax like this, where in this example we get all images of filesystems created in the last day:

    $imagelist = Get-AGMLibImageRange -apptype FileSystem -appliancename sa-sky -olderlimit 1
    If we know that images created in the last 24 hours are all infected, we could use this (up to 3 days old but not less than 1 day old):

    $imagelist = Get-AGMLibImageRange -apptype FileSystem -appliancename sa-sky -olderlimit 3 -newerlimit 1
    We can also use the Template Name (SLT) to find our apps. This is a handy way to separate apps since you can create as many SLTs as you like and use them as a unique way to group apps.

    $imagelist = Get-AGMLibImageRange -sltname FSSnaps_RW_OV -olderlimit 3 -newerlimit 1

    Editing your Imagelist:

    You could create a CSV of images, edit it and then convert that into an object. This would let you delete all the images you don't want to recover, or create chunks to recover (say 20 images at a time)

    In this example we grab 20 days of images:

    Get-AGMLibImageRange -apptype FileSystem -appliancename sa-sky -olderlimit 20 -csvfile images.csv
    We now edit the CSV we created images.csv to remove images we don't want. We then import what is left into our $imagelist variable:

    $imagelist = Import-Csv -Path .\images.csv
    Now we have our image list, we can begin to create our recovery command.
        
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

    if ((!($appid)) -and (!($appname)) -and (!($fuzzyappname)) -and (!($apptype)) -and (!($sltname)) -and (!($every)))
    { 
        Clear-Host
        write-host "This is a function to find a range of images available for an application"
        Write-host "We need to search either with appid, appname, fuzzyappname, apptype or sltname"
        write-host "Alternatively we can just grab every image"
        write-host ""
        write-host "Please read the help for this command carefully to determine how to use the output.  Get-Help Get-AGMLibImageRange"
        write-host ""
        Write-Host "1`: Run a guided menu to help me build a command (default)"
        Write-Host "2`: Exit"
        $userchoice = ""
        $userchoice = Read-Host "Please select from this list (1-2)"
        if ($userchoice -eq 2) { return }
        Clear-Host
        $appliancegrab = Get-AGMAppliance | select-object name,clusterid | sort-object name
        if ($appliancegrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any appliances to work with"
            return
        }
        if ($appliancegrab.count -gt 1)
        {
            Clear-Host
            write-host "Appliance selection menu - which Appliance will run these mounts."
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
            $clusterid =  $appliancegrab.clusterid[($appselection - 1)]
            $appliancename =  $appliancegrab.name[($appselection - 1)]
        }
        $userchoice = ""
        Clear-Host
        Write-host ""
        Write-host "Do you want to work with local or imported images"
        Write-host ""
        Write-Host "1`: Imported images only (default)"
        Write-Host "2`: Local images"
        $impchoice = Read-Host "Please select from this list (1-2)"
        if ($impchoice -eq "" -or $impchoice -eq "1")
        {
            $appliancefilter = ""
            $imagefilter = ""
            foreach ($appliance in $appliancegrab)
            { 
                $appliancefilter = $appliancefilter +"&sourcecluster!" +$appliance.clusterid 
                $imagefilter = $imagefilter +"&sourceuds!" +$appliance.clusterid 
            }
            $appliancefilter = $appliancefilter.Substring(1) 
            $imagefilter = $imagefilter.Substring(1) 
            $imported = $true
        }
        else {
            $appliancefilter = 'sourcecluster=' +$clusterid 
        }


        write-host ""
        Write-host "Search method"
        Write-host ""
        Write-Host "1`: appid"
        Write-Host "2`: appname"
        Write-Host "3`: apptype"
        Write-Host "4`: fuzzyappname"
        Write-Host "5`: sltname (known locally)"
        Write-Host "6`: sltname (unknown locally - this can be very slow)"
        Write-Host "7`: give me everything"
        While ($true) 
        {
            Write-host ""
            $userchoice = Read-Host "Please select from this list (1-6)"
            if ($userchoice -lt 1 -or $userchoice -gt 7)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-6]"
            } 
            else
            {
                break
            }
        }


        if ($userchoice -eq 1) 
        {

            $datagrab = Get-AGMApplication -filtervalue $appliancefilter -sort "hostname:asc,appname:asc,apptype:asc" 
            
            if ($datagrab.id.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Did not find any Applications"
                return
            }
            $printarray = @()
            $i = 1
            foreach ($app in $datagrab)
            {
                $printarray += [pscustomobject]@{
                    id = $i
                    appid = $app.id
                    hostname = $app.host.hostname
                    appname = $app.appname
                    apptype = $app.apptype
                }
                $i += 1
            }
            clear-host
            write-host "Please select an application"
            $printarray | Format-Table 
            $listmax = $printarray.appid.count
            While ($true) 
            {
                [int]$userchoice1 = Read-Host "Please select from this list (1-$listmax)"
                if ($userchoice1 -lt 1 -or $userchoice1 -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $appid = $printarray.appid[$userchoice1-1]
        }
        if ($userchoice -eq 2) 
        {

            $datagrab = Get-AGMApplication -filtervalue $appliancefilter -sort "hostname:asc,appname:asc,apptype:asc" 
            if ($datagrab.id.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Did not find any Applications"
                return
            }
            $printarray = @()
            $i = 1
            foreach ($app in $datagrab)
            {
                $printarray += [pscustomobject]@{
                    id = $i
                    appid = $app.id
                    hostname = $app.host.hostname
                    appname = $app.appname
                    apptype = $app.apptype
                }
                $i += 1
            }
            clear-host
            write-host "Please select an application"
            $printarray | Format-Table 
            $listmax = $printarray.appid.count
            While ($true) 
            {
                [int]$userchoice2 = Read-Host "Please select from this list (1-$listmax)"
                if ($userchoice2 -lt 1 -or $userchoice2 -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $appname = $printarray.appname[$userchoice2-1]
        }
        if ($userchoice -eq 3) 
        {
            $datagrab = Get-AGMApplicationTypes 
            if ($datagrab.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Did not find any Application types"
                return
            }
            Clear-Host
            write-host "Please select an application type"
            $i = 1
            foreach ($type in $datagrab)
            { 
                Write-Host -Object "$i`: $type"
                $i++
            }
            $userselection = ""
            Write-host ""
            $listmax = $datagrab.count
            While ($true) 
            {
                [int]$userselection = Read-Host "Please select an Application Type (1-$listmax)"
                if ($userselection -lt 1 -or $userselection -gt $listmax)
                {
                    Write-Host -Object "Please select a value between 1 and $listmax"
                } 
                else
                {
                    break
                }
            }
            $apptype=$datagrab[($userselection - 1)]
        }
        if ($userchoice -eq 4) 
        {

            $datagrab = Get-AGMApplication -filtervalue $appliancefilter -sort "hostname:asc,appname:asc,apptype:asc" 
            
            if ($datagrab.id.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Did not find any Applications"
                return
            }
            $printarray = @()
            $i = 1
            foreach ($app in $datagrab)
            {
                $printarray += [pscustomobject]@{
                    id = $i
                    appid = $app.id
                    hostname = $app.host.hostname
                    appname = $app.appname
                    apptype = $app.apptype
                }
                $i += 1
            }
            clear-host
            write-host "Please examine the app names to determine a good fuzzy appname"
            $printarray | Format-Table 
            $listmax = $printarray.appid.count
            While ($true) 
            {
                [string]$fuzzyappname = Read-Host "Please enter a fuzzy app name"
                if ($fuzzyappname -eq "")
                {
                    Write-Host -Object "Fuzzy appname cannot be blank"
                } 
                else
                {
                    break
                }
            }
        }
        if ($userchoice -eq 5) 
        {
            $datagrab = Get-AGMSLT -sort name:asc
            if ($datagrab.id.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Did not find any SLTs"
                return
            }
            Clear-Host
            $i = 1
            foreach ($sltname in $datagrab.name)
            { 
                Write-Host -Object "$i`: $sltname"
                $i++
            }
            $userselection = ""
            Write-host ""
            $listmax = $datagrab.name.count
            While ($true) 
            {
                [int]$userselection = Read-Host "Please select an SLT (1-$listmax)"
                if ($userselection -lt 1 -or $userselection -gt $listmax)
                {
                    Write-Host -Object "Please select a value between 1 and $listmax"
                } 
                else
                {
                    break
                }
            }
            $sltname =  $datagrab.name[($userselection - 1)]
        } 
        if ($userchoice -eq 6) 
        {
            # learn all known SLT names and create filter list to exclude them
            $sltnamegrab = Get-AGMSLT -sort name:asc
            foreach ($slt in $sltnamegrab)
            {
                $sltfilter = $sltfilter + "&sltname!" + $slt.name
            }

            # chunk through all images that have unknown slt names.   This can take a while but is how we learn SLT names of imported images without known SLT names.
            $sltgrab = Get-AGMImage -filtervalue $sltfilter | select-object sltname
            if ($sltgrab.sltname.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "Did not find any SLTs"
                return
            }
            $datagrab = $sltgrab | sort-object sltname | Get-Unique -asstring
            Clear-Host
            $i = 1
            foreach ($name in $datagrab.sltname)
            { 
                Write-Host -Object "$i`: $name"
                $i++
            }
            $userselection = ""
            Write-host ""
            $listmax = $datagrab.sltname.count
            While ($true) 
            {
                [int]$userselection = Read-Host "Please select an SLT (1-$listmax)"
                if ($userselection -lt 1 -or $userselection -gt $listmax)
                {
                    Write-Host -Object "Please select a value between 1 and $listmax"
                } 
                else
                {
                    break
                }
            }
            $sltname =  $datagrab.sltname[($userselection - 1)]
        }  
        Clear-Host
        Write-host "We need to determine what time period method we use to find images."
        Write-host ""
        Write-Host "1`: Search in days (default)"
        Write-Host "2`: Search in hours"
        [int]$userchoice = Read-Host "Please select from this list (1-2)"
        if ($userchoice -eq 2) { $hours = $true }
        if ($hours)
        {
            write-host "The Olderlimit determines how far back in time we look for images.  By default it is 1 hour."
            [int]$olderlimit = Read-Host "Olderlimit"
            write-host "The Newerlimit determines how close to today we look for images. If you specify 2, then no image created in the last 2 hours will be listed"
            [int]$newerlimit = Read-Host "Newerlimit"
        } 
        else    
        {
            write-host "The Olderlimit determines how far back in time we look for images.  By default it is 1 day."
            [int]$olderlimit = Read-Host "Olderlimit"
            write-host "The Newerlimit determines how close to today we look for images. If you specify 2, then no image created in the last 2 days will be listed"
            [int]$newerlimit = Read-Host "Newerlimit"

        }
        Write-host "Optionally you can supply a consistency date in ISO format to use as the date to work with rather than the current date"
        [string]$consistencydate = Read-Host "Hit enter or type a date in format like 2021-07-28 12:00"

        Write-host "We need to determine which jobclass to display."
        Write-host ""
        Write-Host "1`: OnVault only (default)"
        Write-Host "2`: Snapshot and OnVault"
        Write-Host "3`: Snapshot only"
        [int]$userchoice = Read-Host "Please select from this list (1-3)"
        if ($userchoice -eq "") { $jobclass = "OnVault" }
        if ($userchoice -eq 1) { $jobclass = "OnVault" } 
        if ($userchoice -eq 2) { $onvault = $true }
        

        [string]$csvfile = Read-Host "Please supply a file name to write out a CSV file (or press enter to display to the screen)"
        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        write-host -nonewline "Get-AGMLibImageRange"
        if ($appid) { write-host -nonewline " -appid $appid" }
        if ($appname) { write-host -nonewline " -appname $appname" }
        if ($sltname) { write-host -nonewline " -sltname $sltname" }
        if ($apptype) { write-host -nonewline " -apptype $apptype" }
        if ($olderlimit) { write-host -nonewline " -olderlimit $olderlimit" }
        if ($newerlimit) { write-host -nonewline " -newerlimit $newerlimit" }
        if ($hours) { write-host -nonewline " -hours" }
        if ($jobclass) { write-host -nonewline " -jobclass $jobclass" }
        if ($onvault) { write-host -nonewline " -onvault" }
        if ($csvfile) { write-host -nonewline " -csvfile $csvfile" }
        if ($clusterid) { write-host -nonewline " -clusterid $clusterid"}
        if ($imported) { write-host -nonewline " -imported"}
        Write-Host ""
        Write-Host "1`: Run the command now (default)"
        Write-Host "2`: Exit without running the command"
        $appuserchoice = Read-Host "Please select from this list (1-2)"
        if ($appuserchoice -eq 2) { return }
    }

    if ($csvfile)
    {
        if ( Test-Path $csvfile )
        {
            Get-AGMErrorMessage -messagetoprint "Filename $csvfile already exists.  Please use a unique filename."
            return
        }
    }
    # just to start fv off
    $fv = ""
    # normally I expect to have one of these three, but only one, not all three
    if ($appid)
    { 
        $fv = "appid=$appid"
    }
    elseif ($appname)
    {
        $fv = "appname=" + $appname
    }
    elseif ($fuzzyappname)
    {
        $fv = "appname~" + $fuzzyappname
    }
    # what about apptype
    if ($apptype) 
    {
        $fv = $fv + "&apptype=" + $apptype
    }


    # search for sltname
    if ($sltname) 
    {
        $fv = $fv + "&sltname=" + $sltname
    }
 
    # if after all this the first character in fv is & we have an issue, so chop it off
    if ($fv)
    {
        if ($fv.substring(0,1) -eq "&")
        {
            $fv=$fv.substring(1) 
        }
    }

    $appfv = $fv
    # powershell is not case sensitive, but AGM jobclasses are, so this is a nice way to make sure the right case gets sent to AGM
    if ($jobclass -eq "onvault") {  $jobclass = "OnVault" }
    if ($jobclass -eq "snapshot") {  $jobclass = "snapshot" }

    if ($jobclass) 
    {
        $fv = $fv + "&jobclass=" +$jobclass
    }
    else
    {
        $fv = $fv + "&jobclass=snapshot"
    }   

    # we offer two ways to ask for onvault, either -jobclass onVault   or just  -onvault  or even -o
    if ($onvault) 
    {
        $fv = $fv + "&jobclass=OnVault"
    }


    if ($appliancename)
    { 
        $clusterid = (Get-AGMAppliance -filtervalue name=$appliancename).clusterid
        if (!($clusterid))
        {
            Get-AGMErrorMessage -messagetoprint "Could not convert appliancename $appliancename into a clusterid."
            return
        }
    }

    if ($clusterid) 
    {
        $fv = $fv + "&clusterid=$clusterid"
    }

    if ($imported)
    {
        $appliancegrab = Get-AGMAppliance | select-object name,clusterid | sort-object name
        foreach ($appliance in $appliancegrab)
        { 
            $fv = $fv +"&sourceuds!" +$appliance.clusterid 
        }
            
    }
    
    if ( (!($newerlimit)) -and (!($olderlimit)) )
    {
        if (!($consistencydate))
        {
            [datetime]$consistencydate = (Get-date).AddMinutes(1).ToString('yyyy-MM-dd HH:mm:ss')
        }
        if ($hours)
        { 
            [datetime]$lowerrange = (Get-date).Addhours(-1).ToString('yyyy-MM-dd HH:mm:ss')
        }
        else 
        {
            [datetime]$lowerrange = (Get-date).adddays(-1).ToString('yyyy-MM-dd HH:mm:ss')
        }
        $fv = $fv + "&consistencydate>$lowerrange"
    }
    elseif ( ($newerlimit) -and (!($olderlimit)) )
    {
        if (!($consistencydate))
        {
            Get-AGMErrorMessage -messagetoprint "A newerlimit was specified without a consistency date in the past to search forward from."
            return
        }
        $lowerrange = $consistencydate.ToString('yyyy-MM-dd HH:mm:ss')
        if ($hours)
        { 
            [datetime]$upperrange = ($consistencydate).Addhours($newerlimit).ToString('yyyy-MM-dd HH:mm:ss')
        }
        else 
        {
            [datetime]$upperrange = ($consistencydate).adddays($newerlimit).ToString('yyyy-MM-dd HH:mm:ss')
        }
        $fv = $fv + "&consistencydate>$lowerrange&consistencydate<$upperrange"
    }
    elseif ( (!($newerlimit)) -and ($olderlimit) )
    {
        if (!($consistencydate))
        {
            [datetime]$consistencydate = (Get-date).AddMinutes(1).ToString('yyyy-MM-dd HH:mm:ss')
        }
        $upperrange = $consistencydate.ToString('yyyy-MM-dd HH:mm:ss')
        if ($hours)
        { 
            [datetime]$lowerrange = ($consistencydate).Addhours(-$olderlimit).ToString('yyyy-MM-dd HH:mm:ss')
        }
        else 
        {
            [datetime]$lowerrange = ($consistencydate).adddays(-$olderlimit).ToString('yyyy-MM-dd HH:mm:ss')
        }
        $fv = $fv + "&consistencydate>$lowerrange&consistencydate<$upperrange"
    }
    else 
    {
        if ($consistencydate)
        {
            if ($hours)
            { 
                [datetime]$upperrange = ($consistencydate).Addhours($newerlimit).ToString('yyyy-MM-dd HH:mm:ss')
                [datetime]$lowerrange = ($consistencydate).Addhours(-$olderlimit).ToString('yyyy-MM-dd HH:mm:ss')
            }
            else 
            {
                [datetime]$upperrange = ($consistencydate).adddays($newerlimit).ToString('yyyy-MM-dd HH:mm:ss')
                [datetime]$lowerrange = ($consistencydate).adddays(-$olderlimit).ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
        else 
        {
            if ($hours)
            { 
                [datetime]$lowerrange = (Get-date).Addhours(-$olderlimit).ToString('yyyy-MM-dd HH:mm:ss')
                [datetime]$upperrange = ($lowerrange ).Addhours($newerlimit).ToString('yyyy-MM-dd HH:mm:ss')
                
            }
            else 
            {
                [datetime]$lowerrange = (Get-date).adddays(-$olderlimit).ToString('yyyy-MM-dd HH:mm:ss')
                [datetime]$upperrange = ($lowerrange).adddays($newerlimit).ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
        $fv = $fv + "&consistencydate>$lowerrange&consistencydate<$upperrange"
    }

      # if after all this the first character in fv is & we have an issue, so chop it off
      if ($fv)
      {
          if ($fv.substring(0,1) -eq "&")
          {
              $fv=$fv.substring(1) 
          }
      }

    $imagegrab = Get-AGMImage -filtervalue "$fv" -sort ConsistencyDate:desc
    $applicationgrab = Get-AGMApplication -filtervalue "$appfv"
    if ($imagegrab.id)
    {
        $AGMArray = @()

        Foreach ($id in $imagegrab)
        { 
            $id | Add-Member -NotePropertyName appid -NotePropertyValue $id.application.id
            $ostype = ($applicationgrab |  where-object {$_.id -eq $id.application.id} | select-object host).host.ostype
            $id | Add-Member -NotePropertyName ostype -NotePropertyValue $ostype
            $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.cluster.name
            $id | Add-Member -NotePropertyName hostname -NotePropertyValue $id.host.hostname
            $AGMArray += [pscustomobject]@{
                apptype = $id.apptype
                ostype = $id.ostype
                hostname = $id.hostname
                appname = $id.appname
                appid = $id.appid
                appliancename = $id.appliancename
                jobclass = $id.jobclass
                jobclasscode = $id.jobclasscode
                backupname = $id.backupname
                id = $id.id
                consistencydate = $id.consistencydate
                endpit = $id.endpit
                label = $id.label
                sltname = $id.sltname
            }
        }
        if ($onvault)
        {
            if (!($csvfile))
            {
                $AGMArray | Select-Object apptype, appliancename, sltname,ostype, hostname, appname, appid, jobclass, jobclasscode, backupname, id, consistencydate, endpit, label | sort-object hostname,appname,consistencydate,jobclasscode
            }
            else {
                $AGMArray | Select-Object apptype, appliancename, sltname, ostype, hostname, appname, appid, jobclass, jobclasscode, backupname, id, consistencydate, endpit, label | sort-object hostname,appname,consistencydate,jobclasscode | Export-Csv -Path $csvfile
                write-host "Wrote" $imagegrab.id.count "images to file "$csvfile
            }
        }
        else 
        {
            if (!($csvfile))
            {
                $AGMArray | Select-Object apptype, appliancename, sltname, ostype, hostname, appname, appid, jobclass, jobclasscode, backupname, id, consistencydate, endpit, label | sort-object hostname,appname,consistencydate
            }
            else {
                $AGMArray | Select-Object apptype, appliancename, sltname, ostype, hostname, appname, appid, jobclass, jobclasscode, backupname, id, consistencydate, endpit, label | sort-object hostname,appname,consistencydate | Export-Csv -Path $csvfile
                write-host "Wrote" $imagegrab.id.count "images to file "$csvfile
            }
        }
    }
    else
    {
        if (!($csvfile))
        {
            $imagegrab
        }
        else {
            $imagegrab | Export-Csv -Path $csvfile
            write-host "Wrote" $imagegrab.id.count "images to file "$csvfile
        }
    }
}