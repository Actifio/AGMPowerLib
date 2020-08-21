Function New-AGMLibContainerMount ([int]$appid,[string]$appname,[string]$allowedips,[int]$imageid,[string]$imagename,[string]$label,[string]$volumes,[switch][alias("g")]$guided,[switch][alias("m")]$monitor,[switch][alias("w")]$wait) 
{
    <#
    .SYNOPSIS
    Mounts an image to a container

    .EXAMPLE
    New-AGMLibContainerMount 

    Runs a guided menu to mount an image to a container

    .EXAMPLE
    New-AGMLibVMExisting -imageid 54380607 -volumes "dasvol:/dev/hanavg/log;/tmp/cmounts/test1;/custmnt2,dasvol:/dev/hanavg/data;/tmp/cmounts/test2;/ss" -allowedips "1.1.1.1,10.10.10.10"

    Mounts Image ID 54380607
    The -volumes list each moint point in the image.  Each mount point is comma separated
    For each each mountpoint we need three values, that are semi-colon separated
    In this example, there are two mount points, the first one is /dev/hanavg/log.
    It is given an appliance mountpoint of /test1 and an NFS export path of /custmnt2

    The allowedips is a comma separated list of IP addresses that can connect to the appliance mountpoint.

    .DESCRIPTION
    A function to mount images to containers

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



    if ( (!($appname)) -and (!($imagename)) -and (!($imageid)) -and (!($appid)) )
    {
        $guided = $true
        $appname = read-host "Which appname do you want to work with"
    }
    

    # if we got a VMware appname lets check it right now
    if ( ($appname) -and (!($appid)) )
    {
        $appgrab = Get-AGMApplication -filtervalue "appname=$appname"
        if ($appgrab.id.count -ne 1)
        { 
            Get-AGMErrorMessage -messagetoprint "Failed to resolve $appname to a unique valid app.  Use Get-AGMLibApplicationID and try again specifying -appid."
            return
        }
        else {
            $appid = $appgrab.id
        }
    }

    # if the user didn't specify a target we need to ask for one now
    if (!($allowedips)) 
    {
        [string]$allowedips = Read-Host "Allowed IP addresses (comma separated list)"
    }    

    # learn about the image if the user gave it
    if ($imagename)
    {
        $imagegrab = Get-AGMImage -filtervalue backupname=$imagename
        if (!($imagegrab))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imagename using:  Get-AGMImage -filtervalue backupname=$imagename"
            return
        }
        else 
        {
            $imageid = $imagegrab.id
        }
    }

    # finally if the user gave an AppID lets check it
    if ($appid)
    {
        $imagegrab = Get-AGMLibLatestImage $appid
        if (!($imagegrab.backupname))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find snapshot for AppID using:  Get-AGMLatestImage $appid"
            return
        }   
        else 
        {
            $imagename = $imagegrab.backupname
            $imageid = $imagegrab.id
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

        $imagegrab = Get-AGMimage -id $imageid 
        $vollist = $imagegrab.restorableobjects 
    
        if (!($vollist))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to fetch any volumes"
            return
        }
        if ($vollist.volumeinfo.count -eq 1) 
        {
            $uniqueid = $imagegrab.restorableobjects.volumeinfo.uniqueid
            $logicalname = $imagegrab.restorableobjects.volumeinfo.logicalname
            $appliancemountpoint = Read-Host "Appliance mount point for $logicalname"
            $mountpoint = Read-Host "NFS Export Path for $logicalname"
            if ($appliancemountpoint)
            {
                if ($appliancemountpoint.substring(0,1) -ne "/")
                {
                    $appliancemountpoint = "/tmp/cmounts/" + $appliancemountpoint
                }
                else {
                    $appliancemountpoint = "/tmp/cmounts" + $appliancemountpoint
                }
            }
            $volumes = $uniqueid + ";" + "$appliancemountpoint" + ";" + $mountpoint
        }
        else
        {
            
            foreach ($point in $vollist.volumeinfo)
            { 
                $uniqueid = $point.uniqueid
                $logicalname = $point.logicalname
                $appliancemountpoint = Read-Host "Appliance mount point for $logicalname"
                $mountpoint = Read-Host "NFS Export Path for $logicalname"
                write-host ""
                if ($appliancemountpoint)
                {
                    if ($appliancemountpoint.substring(0,1) -ne "/")
                    {
                        $appliancemountpoint = "/tmp/cmounts/" + $appliancemountpoint
                    }
                    else {
                        $appliancemountpoint = "/tmp/cmounts" + $appliancemountpoint
                    }
                }
                $volumes = $volumes + "," + $uniqueid + ";" + "$appliancemountpoint" + ";" + $mountpoint
            }
            $volumes = $volumes.substring(1)
            
        }

        Clear-Host
        Write-Host "Guided selection is complete.  The values entered would result in the following command:"
        Write-Host ""
        Write-Host -nonewline "New-AGMLibVMExisting -imageid $imageid -volumes `"$volumes`""
        if ($allowedips)
        {
            Write-Host -nonewline " -allowedips `"$allowedips`""
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


    
    if (!($imageid))
    {
        [int]$imageid = Read-Host "ImageID to mount"
    }


    $selectedobjects = @(
        [pscustomobject]@{restorableobject=$appname}
    )



    if ($volumes)
    {
        $restoreobjectmappings =@(
        foreach ($vol in $volumes.Split(","))
        {
            [ordered]@{
                'restoreobject' = $vol.split(";")[0]
                'appliancemountpoint' = $vol.split(";")[1]
                'mountpoint' = $vol.split(";")[2]
            }
        }
        )
    }

    if (!($label))
    {
        $label = ""
    }

    $body = [ordered]@{
        label = $label;
        container = "true";
        selectedobjects = $selectedobjects;
        restoreobjectmappings = $restoreobjectmappings
    }

    if ($allowedips)
    {
        $allowediplist = @(foreach ($ip in $allowedips.Split(","))
        {
            $ip
        }
        )
        $body = $body + [ordered]@{ allowedips = $allowediplist }
    }

    $json = $body | ConvertTo-Json

    if ($monitor)
    {
        $wait = "y"
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
        $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=false&targethost=$targethostname" -sort queuedate:desc -limit 1 
        if (!($jobgrab.jobname))
        {
            Start-Sleep -s 15
            $jobgrab = Get-AGMJob -filtervalue "appid=$appid&jobclasscode=5&isscheduled=false&targethost=$targethostname" -sort queuedate:desc -limit 1 
            if (!($jobgrab.jobname))
            {
                return
            }
        }
        else
        {   
            $jobgrab| select-object jobname,status,queuedate,startdate,targethost
            
        }
        if (($jobgrab.jobname) -and ($monitor))
        {
            Get-AGMFollowJobStatus $jobgrab.jobname
        }
    }
}
