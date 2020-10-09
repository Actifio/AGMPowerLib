Function Set-AGMLibMSSQLMigrate ([string]$imagename,[string]$imageid,[int]$copythreadcount,[int]$frequency,[string]$srcid,[switch]$jsonprint) 
{
    <#
    .SYNOPSIS
    Configures migrate settings for a mounted MS SQL Image

    .EXAMPLE
    Set-AGMLibMSSQLMigrate 
    You will be prompted for ImageID

    .EXAMPLE
    Set-AGMLibMSSQLMigrate -imageid 56072427 -copythreadcount 2 -frequency 2

    Changes the copy thread count to 2 and frequency to 2 hours for Image ID 56072427

    .DESCRIPTION
    A function to configure migration for an MS SQL Image

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
        $backup = Get-AGMImage -filtervalue "characteristic=MOUNT&apptype=SqlInstance&apptype=SqlServerWriter" 
        if ($backup.id.count -gt 0)
        {
            $AGMArray = @()
            $i = 1
            Foreach ($id in $backup)
            { 
                if ( $id.flags_text -contains "JOBFLAGS_MIGRATING")
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

                    }
                    $i++
                }
            }
            if ($AGMArray.imageid.count -eq 0)
            {
                Get-AGMErrorMessage -messagetoprint "There are no migrating SQL App Type apps to list"
                return
            }
            Clear-Host
            Write-Host "Image list.  Choose your image."
            $i = 1
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
            $imageid =  $AGMArray[($imageselection - 1)].imageid
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
        $imagegrab = get-agmimage -id $imageid
        if (!($imagegrab.id))
        {
            Get-AGMErrorMessage -messagetoprint "Could not find image $imageid"
            return
        }

        if ($imagegrab.'migrate-configured' -ne "True")
        {
            Get-AGMErrorMessage -messagetoprint "$imageid does not have migration configured.   Please configure this first with New-AGMLibMSSQLMigrate"
            return
        }

        if (!($frequency))
        { 
            [int]$frequency = Read-Host "Frequency (currently $($imagegrab.'migrate-frequency'))"
        }
        if (!($frequency))
        { 
            [int]$frequency = $($imagegrab.'migrate-frequency')
        }

        if (!($copythreadcount))
        { 
            [int]$copythreadcount = Read-Host "Copy thread count (currently $($imagegrab.'migrate-copythreadcount'))"
        }
        if (!($copythreadcount))
        { 
            [int]$copythreadcount = $($imagegrab.'migrate-copythreadcount')
        }
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

    $body = [ordered]@{}

    $provisioningoptions = @()
    if ($copythreadcount) { $provisioningoptions += @( @{ name = 'copythreadcount'; value = $copythreadcount } ) }

    
    $body += @{ provisioningoptions = $provisioningoptions }
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