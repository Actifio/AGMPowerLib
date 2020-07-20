Function Get-AGMLibApplicationID ([string]$appname) 
{
    <#
    .SYNOPSIS
    Displays the App IDs for a nominated AppName.

    .EXAMPLE
    Get-AGMLibApplicationID
    You will be prompted for AppName

    .EXAMPLE
    Get-AGMLibApplicationID smalldb
    To search for the AppID of any apps called smalldb

    .DESCRIPTION
    A function to find any Apps with nominated name

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }

    if (!($appname))
    {
        $appname = Read-Host "AppName"
    }
         
    $output = Get-AGMApplication -filtervalue appname=$appname
    if ($output.id)
    {
        $AGMArray = @()

        Foreach ($id in $output)
        { 
            $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.cluster.name
            $id | Add-Member -NotePropertyName applianceip -NotePropertyValue $id.cluster.ipaddress
            $id | Add-Member -NotePropertyName appliancetype -NotePropertyValue $id.cluster.type
            $id | Add-Member -NotePropertyName hostname -NotePropertyValue $id.host.hostname
            $AGMArray += [pscustomobject]@{
                id = $id.id
                friendlytype = $id.friendlytype
                hostname = $id.hostname
                appname = $id.appname
                appliancename = $id.appliancename
                applianceip = $id.applianceip
                appliancetype = $id.appliancetype
                managed = $id.managed
            }
        }
        $AGMArray | FT -AutoSize | Sort-Object -Property hostname -Descending
    }
    else
    {
        $output
    }
}
