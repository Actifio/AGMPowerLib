Function New-AGMLibMSSQLMigrate ([string]$imagename,[string]$imageid,[int]$copythreadcount,[int]$frequency,[string]$srcid,[switch]$jsonprint,[switch]$dontrenamedatabasefiles,[switch]$volumes,[switch]$files,[switch]$usesourcelocation,[string]$restorelist,[switch][alias("g")]$guided) 
{
    <#
    .SYNOPSIS
    Creates a migration for a mounted MS SQL Image

    .EXAMPLE
    New-AGMLibMSSQLMigrate 
    You will be prompted for ImageID

    .EXAMPLE
    New-AGMLibMSSQLMigrate -imageid 56072427 -copythreadcount 2 -frequency 2

    Sets the copy thread count to 2 and frequency to 2 hours for Image ID 56072427

    .DESCRIPTION
    A function to create migration for an MS SQL Image

    Note the default is to rename files to match new database name.  To override this use -dontrenamedatabasefiles

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

    if (($imagename) -and (!($imageid)))
    {
        $imageid = (Get-AGMImage -filtervalue backupname=$imagename).id
    }

    if (!($imageid))
    {
        $imageid = Read-host "Image ID (press enter for a list)"
    }

    if (!($imageid))
    {
        $backup = Get-AGMImage -filtervalue "characteristic=MOUNT&apptype=SqlInstance&apptype=SqlServerWriter" 
        if ($backup.id)
        {
            $AGMArray = @()

            Foreach ($id in $backup)
            { 
                $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.cluster.name
                $id | Add-Member -NotePropertyName hostname -NotePropertyValue $id.host.hostname
                $id | Add-Member -NotePropertyName appid -NotePropertyValue $id.application.id
                $id | Add-Member -NotePropertyName mountedhostname -NotePropertyValue $id.mountedhost.hostname
                $id | Add-Member -NotePropertyName childappname -NotePropertyValue $id.childapp.appname
                
                $AGMArray += [pscustomobject]@{
                    id = $id.id
                    apptype = $id.apptype
                    appliancename = $id.appliancename
                    hostname = $id.hostname
                    appname = $id.appname
                    mountedhost = $id.mountedhostname
                    childappname = $id.childappname
                    label = $id.label
                    files = $id.restorableobjects.fileinfo
                    volumes = $id.restorableobjects.volumeinfo.logicalname
                }
            }
            Clear-Host
            Write-Host "Image list.  Choose your image."
            $i = 1
            foreach ($image in $AGMArray)
            { 
                Write-Host -Object "$i`:  $($image.id) ($($image.childappname) mounted on $($image.mountedhost))"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $AGMArray.Length
                [int]$imageselection = Read-Host "Please select an image (1-$listmax)"
                if ($imageselection -lt 1 -or $imageselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax]"
                } 
                else
                {
                    break
                }
            }
            $imageid =  $AGMArray[($imageselection - 1)].id
            $srcid = $AGMArray[($imageselection - 1)].application.srcid
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "There are no mounted SQL App Type apps to list"
            return
        }
    }

    if ((!($frequency)) -and (!($copythreadcount)))
    {   
        if (!($frequency))
        { 
            [int]$frequency = Read-Host "Frequency (hit enter for default of 24 hours)"
        }
        if (!($frequency))
        { 
            [int]$frequency = 24
        }

        if (!($copythreadcount))
        { 
            [int]$copythreadcount = Read-Host "Copy thread count (hit enter for default of 4 threads)"
        }
        if (!($copythreadcount))
        { 
            [int]$copythreadcount = 4
        }
    }

    if ((!($usesourcelocation)) -and (!($restorelist)))
    {
        Clear-Host
        Write-Host "Rename files to match new database name"
        Write-Host "1`: Rename files to match new database name (default)"
        Write-Host "2`: Don't rename files"
        [int]$userselection = Read-Host "Please select from this list (1-2)"
        if ($userselection -eq "") { $userselection = 1 }
        if ($userselection -eq 1) {  $dontrenamedatabasefiles = $FALSE }
        if ($userselection -eq 2) {  $dontrenamedatabasefiles = $TRUE }
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
            if (!($AGMArray.volumes))
            {
                $filelist = (Get-AGMImage -id $imageid).restorableobjects.volumeinfo.logicalname
            }
            else {
                $filelist = $AGMArray.files
            }
        }
        if ($userselection -eq 3)
        {
            if (!($AGMArray.files))
            {
                $filelist = (Get-AGMImage -id $imageid).restorableobjects.fileinfo
            }
            else {
                $filelist = $AGMArray.files
            }
        }
        if ($userselection -eq 2) 
        {
            Write-host "`n For each volume please specify a new volume"
            $restorelist = ""
            
            write-host ""
            foreach ($file in $filelist)
            {
                $targetlocation = ""
                $targetlocation = read-host "Source: $($file)   Target"
                if ($targetlocation -eq "")
                { 
                    $targetlocation = $file
                }
                $restorelist = $restorelist + ";" + $file + "," + $file + "," + $targetlocation 
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
                $targetlocation = read-host "File: $($file.filename) Source: $($file.filepath)   Target"
                if ($targetlocation -eq "")
                { 
                    $targetlocation = $file.filepath
                }
                $restorelist = $restorelist + ";" + $file.filename + "," + $file.filepath + "," + $targetlocation 
            }
            $restorelist = $restorelist.Substring(1)
            $files = $TRUE
        }
    }

    if ((($files) -or ($volumes)) -and (!($restorelist)) )
    {
        Get-AGMErrorMessage -messagetoprint "Please specify restorelist"
        return
    }

    if (!($srcid))
    {
        if (!($imagegrab.id))
        {
            $imagegrab = get-agmimage -id $imageid
            if (!($imagegrab))
            {
                Get-AGMErrorMessage -messagetoprint "Could not find image $imageid"
                return
            }
        }
        $srcid = $imagegrab.application.srcid
    }

    if ($guided)
    {
        Write-Host "Guided selection is complete.  The values entered would result in the following command:"
        Write-Host ""
        Write-Host -nonewline "New-AGMLibMSSQLMigrate -imageid $imageid -copythreadcount $copythreadcount -frequency $frequency -srcid $srcid -frequency `"$frequency`""
        if ($dontrenamedatabasefiles) {  Write-Host -nonewline " -dontrenamedatabasefiles " }
        if ($volumes) {  Write-Host -nonewline " -volumes " }
        if ($files) {  Write-Host -nonewline " -files " }
        if ($usesourcelocation) {  Write-Host -nonewline " -usesourcelocation " }
        if ($restorelist) {  Write-Host -nonewline " -restorelist `"$restorelist`"" }
        Write-Host ""
        Write-Host "1`: Run the command now (default)"
        Write-Host "2`: Show the JSON used to run this command, but don't run it"
        Write-Host "3`: Exit without running the command"
        $userchoice = Read-Host "Please select from this list (1-3)"
        if ($userchoice -eq 2)
        {
            $jsonprint = $TRUE
        }
        if ($userchoice -eq 3)
        {
            return
        }
    }

    $body = [ordered]@{}
    $mapping = @()
    $provisioningoptions = @()
    $restorelocation = [ordered]@{}
    if ($copythreadcount) { $provisioningoptions += @( @{ name = 'copythreadcount'; value = $copythreadcount } ) }
    if ($dontrenamedatabasefiles) { $provisioningoptions += @( @{ name = 'renamedatabasefiles'; value = "false" } ) } else { $provisioningoptions += @( @{ name = 'renamedatabasefiles'; value = "true" } ) }
    $body += @{ provisioningoptions = $provisioningoptions }
    if ($usesourcelocation)
    {
        $body += @{  restorelocation = @{ type = "usesourcelocation" } }
    }
    if ($volumes)
    {
        foreach ($volume in $restorelist.split(";"))
        {
            $mapping += @( [ordered]@{ name = $volume.split(",")[0] ; source = $volume.split(",")[1] ; target = $volume.split(",")[2] } ) 
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

    
    $application = @{ srcid = $srcid }
    $body += @{  application = $application }
    if ($frequency) { $body += @{ frequency = [int]$frequency }  }

    $json = $body | ConvertTo-Json 


    if ($jsonprint)
    {
        $compressedjson = $body | ConvertTo-Json -compress
        Write-host "This is the final command:"
        Write-host ""
        Write-host "Post-AGMAPIData  -endpoint /backup/$imageid/configmountmigrate -body `'$compressedjson`'"
        return
    }

    Post-AGMAPIData  -endpoint /backup/$imageid/configmountmigrate -body $json
}