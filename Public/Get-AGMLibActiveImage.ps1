Function Get-AGMLibActiveImage([int]$appid, [string]$jobclass,[switch][alias("u")]$unmount) 
{
    <#
    .SYNOPSIS
    Displays all mounts

    .EXAMPLE
    Get-AGMActiveImages
    Displays all active images

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
    
    $fv = "characteristic=MOUNT"
    if ($unmount)
    {
        $fv = "characteristic=UNMOUNT"
    }
    if ($jobclass)
    {
        $fv = "characteristic=MOUNT&jobclass=$jobclass"
    }
    if ($appid) 
    {
        $fv = "characteristic=MOUNT&appid=$id" 
    }
    if ( ($appid) -and  ($jobclass) )
    {
        $fv = "characteristic=MOUNT&appid=$id&jobclass=$jobclass"
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
            $AGMArray += [pscustomobject]@{
                imagename = $id.backupname
                apptype = $id.apptype
                hostname = $id.hostname
                appname = $id.appname
                mountedhostname = $id.mountedhostname
                childappname = $id.childappname
                appliancename = $id.appliancename
                consumedsize = $id.consumedsize
                daysold = $id.daysold
                label = $id.label
            }
        }
        $AGMArray 
    }
    else
    {
        $backup
    }
}