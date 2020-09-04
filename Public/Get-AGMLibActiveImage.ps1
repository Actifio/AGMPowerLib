Function Get-AGMLibActiveImage([int]$appid, [string]$jobclass,[switch][alias("i")]$imageidprint,[switch][alias("n")]$nfsprint,[switch][alias("u")]$unmount) 
{
    <#
    .SYNOPSIS
    Displays all mounts

    .EXAMPLE
    Get-AGMActiveImages
    Displays all active images (mounts)

    .EXAMPLE
    Get-AGMActiveImages
    Displays all active images (mounts)

    .EXAMPLE
    Get-AGMActiveImages -appid 4771
    Displays all active images for the app with ID 4771

    .DESCRIPTION
    A function to find the active images

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
    
    $fv = "characteristic=1&characteristic=2&apptype!nas"
    if ($unmount)
    {
        $fv = $fv + "characteristic=2"
    }
    if ($jobclass)
    {
        $fv = $fv + "&jobclass=$jobclass"
    }
    if ($appid) 
    {
        $fv = $fv + "&appid=$id" 
    }
   
    
    $backup = Get-AGMImage -filtervalue "$fv" 
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
            $startdate=[datetime]$id.modifydate
            $enddate=(GET-DATE)
            $age = NEW-TIMESPAN –Start $StartDate –End $EndDate
            $id | Add-Member -NotePropertyName daysold -NotePropertyValue $age.days 
            if ($id.characteristic -eq "Mount")
            {
                $imagestate = "Mounted"
            }
            else 
            {
                $imagestate = "Unmounted"
            }
            if ($imageidprint)
            {
                $AGMArray += [pscustomobject]@{
                    id = $id.id
                    apptype = $id.apptype
                    appliancename = $id.appliancename
                    hostname = $id.hostname
                    appname = $id.appname
                    mountedhost = $id.mountedhostname
                    allowedip = $id.allowedips
                    childappname = $id.childappname
                    consumedsize_gib = [math]::Round($id.consumedsize / 1073741824,3)
                    daysold = $id.daysold
                    label = $id.label
                    imagestate = $imagestate
                }
            }
            elseif ($nfsprint)
            {
                if ($id.allowedips)
                {
                    $AGMArray += [pscustomobject]@{
                        id = $id.id
                        apptype = $id.apptype
                        appliancename = $id.appliancename
                        hostname = $id.hostname
                        appname = $id.appname
                        allowedip = $id.allowedips
                        consumedsize_gib = [math]::Round($id.consumedsize / 1073741824,3)
                        daysold = $id.daysold
                        label = $id.label
                        imagestate = $imagestate
                    }
                }
            }
            else 
            {
                $AGMArray += [pscustomobject]@{
                    imagename = $id.backupname
                    apptype = $id.apptype
                    appliancename = $id.appliancename
                    hostname = $id.hostname
                    appname = $id.appname
                    mountedhost = $id.mountedhostname
                    allowedip = $id.allowedips
                    childappname = $id.childappname
                    consumedsize_gib = [math]::Round($id.consumedsize / 1073741824,3)
                    daysold = $id.daysold
                    label = $id.label
                    imagestate = $imagestate
                }
            }
        }
        $AGMArray  | sort-Object appliancename,hostname,appname
    }
    else
    {
        $backup
    }
}