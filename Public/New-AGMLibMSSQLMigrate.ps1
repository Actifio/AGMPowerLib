Function New-AGMLibMSSQLMigrate ([string]$imagename,[string]$imageid,[int]$copythreadcount,[int]$frequency,[switch]$jsonprint,[switch]$dontrenamedatabasefiles,[switch]$volumes,[switch]$files,[string]$restorelist,[switch][alias("g")]$guided) 
{
    <#
    .SYNOPSIS
    Creates a migration for a mounted MS SQL Image

    .EXAMPLE
    New-AGMLibMSSQLMigrate 
    You will be prompted for ImageID

    .EXAMPLE
    New-AGMLibMSSQLMigrate -imageid 56072427 

    Starts a migrate with default copy thread of 4 and default frequency set to 24 hours for Image ID 56072427
    Files will be renamed to match the new database name and files will be copied to the same drive/path as they were on the source server

    .EXAMPLE
    New-AGMLibMSSQLMigrate -imagename Image_10557067

    Starts a migrate with default copy thread of 4 and default frequency set to 24 hours for ImageName Image_10557067
    Files will be renamed to match the new database name and files will be copied to the same drive/path as they were on the source server

    .EXAMPLE
    New-AGMLibMSSQLMigrate -imageid 56072427 -copythreadcount 2 -frequency 2

    Starts a migrate with copy thread count set to 2 and frequency set to 2 hours for Image ID 56072427
    Files will be renamed to match the new database name and files will be copied to the same drive/path as they were on the source server

    .EXAMPLE
    New-AGMLibMSSQLMigrate -imagename Image_10557067 -copythreadcount 7 

    Starts a migrate with copy thread count set to 7 and frequency left for the default of 24 hours for ImageName Image_10557067
    Files will be renamed to match the new database name and files will be copied to the same drive/path as they were on the source server

    .EXAMPLE
    New-AGMLibMSSQLMigrate -imageid 6859821 -files  -restorelist "SQL_smalldb.mdf,D:\Data,d:\avtest1;SQL_smalldb_log.ldf,E:\Logs,e:\avtest1"

    Starts a migrate with default copy thread of 4 and default frequency set to 24 hours for ImageID 6859821
    Files will be renamed to match the new database name.
    Because "-files" was specified, the -restorelist must contain the file name, the source location and the targetlocation.
    Each file is separated by a semicolon,  the three fields for each file are comma separated.
    In this example, the file SQL_smalldb.mdf found in D:\Data will be migrated to d:\avtest1
    In this example, the file SQL_smalldb_log found in E:\Logs will be migrated to e:\avtest1
    The order of the fields must be "filename,sourcefolder,targetfolder" so for two files "filename1,source1,target1;filename2,source2,target2"

    .EXAMPLE    
    New-AGMLibMSSQLMigrate -imageid 6860452 -copythreadcount 3 -frequency 2 -volumes  -restorelist "D:\,K:\;E:\,M:\"

    Starts a migrate with copy thread of 3 and frequency set to 24hours for ImageID 6860452
    Files will be renamed to match the new database name.
    Because "-volumes" was specified, the -restorelist must contain the source drive letter and the target drive letter.
    Each drive is separated by a semicolon,  the two fields for each drive are comma separated.
    In this example the D:\ files will be migrated to the K:\
    In this example the E:\ files will be migrated to the M:\
    The order of the fields must be "sourcedrive,targetdrive" so for two drives "sourcedrive1,targetdrive1;sourcedrive2,targetdrive2"

    .DESCRIPTION
    A function to create migration for an MS SQL Image

    The following defaults all apply:
    If frequency is not set with "-frequency XX"  it will default to 24 hours
    If copythreadcount is not set with "-copythreadcount YY" it will default to 4
    If dontrenamedatabasefiles is not set with "-dontrenamedatabasefiles" then files will be renamed to match the new database name
    If a restore list is not specified, then the default will be to copy files to the same drive/path as they were on the source server
    #>


    # its pointless proceeding without a connection.
    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    $sessiontest = Get-AGMVersion
    if (!($sessiontest.summary))
    {
        Get-AGMErrorMessage -messagetoprint "AGM session has expired. Please login again using Connect-AGM"
        return
    }


    if (($imagename) -and (!($imageid)))
    {
        $imageid = (Get-AGMImage -filtervalue backupname=$imagename).id
    }



    if ( (!($imagename)) -and (!($imageid)) )
    {
        $guided = $TRUE
        $backup = Get-AGMImage -filtervalue "characteristic=MOUNT&apptype=SqlInstance&apptype=SqlServerWriter" -sort "hostname:asc,appname:asc"
        if ($backup.id)
        {
            $AGMArray = @()
            $i = 1
            Foreach ($id in $backup)
            { 
                if ( $id.flags_text -notcontains "JOBFLAGS_MIGRATING")
                {
                    $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.cluster.name
                    $id | Add-Member -NotePropertyName hostname -NotePropertyValue $id.host.hostname
                    $id | Add-Member -NotePropertyName appid -NotePropertyValue $id.application.id
                    $id | Add-Member -NotePropertyName mountedhostname -NotePropertyValue $id.mountedhost.hostname
                    $id | Add-Member -NotePropertyName childappname -NotePropertyValue $id.childapp.appname
                    
                    $AGMArray += [pscustomobject]@{
                        select = $i
                        imageid = $id.id
                        imagename = $id.backupname
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
                    $i++
                }
            }
            if ($AGMArray.imageid.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "All mounted SQL Apps are already migrating"
                return
            }
            Clear-Host
            Write-Host "Image list.  Choose your image."
            $AGMArray | select-object select,apptype,hostname,appname,mountedhost,childappname,imageid,imagename  | Format-Table *
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
            $imageid = $AGMArray[($imageselection - 1)].imageid
            $srcid = $AGMArray[($imageselection - 1)].application.srcid
            $imagegrab = Get-AGMImage -id $imageid
            $vollist = $imagegrab.restorableobjects.volumeinfo.logicalname | sort-object -unique
            $filelist = $imagegrab.restorableobjects.fileinfo | sort-object filepath,filename
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
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "There are no mounted SQL App Type apps to list"
            return
        }
    }

    
    if (!($frequency)) 
    {   
        [int]$frequency = 24
    }

    if (!($copythreadcount))
    {
        [int]$copythreadcount = 4
    }

    if (!($restorelist))
    { 
        $usesourcelocation = $TRUE
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
        Write-Host -nonewline "New-AGMLibMSSQLMigrate -imageid $imageid -copythreadcount $copythreadcount -frequency $frequency"
        if ($volumes) {  Write-Host -nonewline " -volumes " }
        if ($files) {  Write-Host -nonewline " -files " }
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
    if ($dontrenamedatabasefiles) { $provisioningoptions += @( [ordered]@{ name = 'renamedatabasefiles'; value = "false" } ) } else { $provisioningoptions += @( [ordered]@{ name = 'renamedatabasefiles'; value = "true" } ) }
    $provisioningoptions += @( [ordered]@{ name = 'copythreadcount'; value = $copythreadcount } ) 
    $body += @{ provisioningoptions = $provisioningoptions }
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

    
    $application = @{ srcid = $srcid }
    $body += @{  application = $application }
    $body += @{ frequency = [int]$frequency } 

    $json = $body | ConvertTo-Json  -depth 4


    if ($jsonprint)
    {
        $compressedjson = $body | ConvertTo-Json -compress -depth 4
        Write-host "This is the final command:"
        Write-host ""
        Write-host "Post-AGMAPIData  -endpoint /backup/$imageid/configmountmigrate -body `'$compressedjson`'"
        return
    }

    Post-AGMAPIData  -endpoint /backup/$imageid/configmountmigrate -body $json
}