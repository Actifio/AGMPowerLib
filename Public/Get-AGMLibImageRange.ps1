Function Get-AGMLibImageRange([string]$appid,[string]$jobclass,[string]$appname,[string]$clusterid,[string]$appliancename,[string]$apptype,[string]$fuzzyappname,[string]$sltname,[datetime]$consistencydate,[int]$newerlimit,[int]$olderlimit,[switch][alias("h")]$hours,[switch][alias("o")]$onvault) 
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

    To get a list of applications, use:  Get-AGMApplication -sort "hostname:asc,appname:asc"| select id, {$_.host.hostname} , appname, apptype, {$_.cluster.name} | format-table
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

    Get-AGMLibImageRange -apptype FileSystem -appliancename sa-sky -olderlimit 20 | Export-Csv -Path .\images.csv
    We now edit the CSV we created images.csv to remove images we don't want. We then import what is left into our $imagelist variable:

    $imagelist = Import-Csv -Path .\images.csv
    Now we have our image list, we can begin to create our recovery command.
        
    #>

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

    if ( (!($fv)) -and ($apptype) )
    {
        $fv = "apptype=" + $apptype
    }
    elseif ( ($fv) -and ($apptype) )
    {
        $fv = $fv + "&apptype=" + $apptype
    }

    # search for policyname
    if ( (!($fv)) -and ($policyname) )
    {
        $fv = "policyname=" + $policyname
    }
    elseif ( ($fv) -and ($policyname) )
    {
        $fv = $fv + "&policyname=" + $policyname
    }

    # search for sltname
    if ( (!($fv)) -and ($sltname) )
    {
        $fv = "sltname=" + $sltname
    }
    elseif ( ($fv) -and ($sltname) )
    {
        $fv = $fv + "&sltname=" + $sltname
    }
 
    if (!($fv))
    { 
        write-host "This is a function to find a range of images available for an application"
        Write-host "Please specify either appid, appname, fuzzyappname, apptype, sltname, or policyname."
        write-host ""
        write-host "Please read the help for this command carefully to determine how to use the output.  Get-Help Get-AGMLibImageRange"
        return
    }

    $appfv = $fv
    # powershell is not case sensitive, but AGM jobclasses are, so this is a nice way to make sure the right case gets sent to AGM
    if ($jobclass -eq "onvault") {  $jobclass = "OnVault" }
    if ($jobclass -eq "snapshot") {  $jobclass = "snapshot" }

    if ($jobclass)
    {
        $fv = $fv + "&jobclass=$jobclass"
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
            }
        }
        if ($onvault)
        {
            $AGMArray | Select-Object apptype, appliancename, ostype, hostname, appname, appid, jobclass, jobclasscode, backupname, id, consistencydate, endpit, label | sort-object hostname,appname,consistencydate,jobclasscode
        }
        else 
        {
            $AGMArray | Select-Object apptype, appliancename, ostype, hostname, appname, appid, jobclass, jobclasscode, backupname, id, consistencydate, endpit, label | sort-object hostname,appname,consistencydate
        }
    }
    else
    {
        $imagegrab
    }




}