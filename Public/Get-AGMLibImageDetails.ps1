Function Get-AGMLibImageDetails ([string]$appid) 
{
    <#
    .SYNOPSIS
    Displays the images for a specified app

    .EXAMPLE
    Get-AGMDBMImageDetails
    You will be prompted for App ID

    .EXAMPLE
    Get-AGMDBMImageDetails 2133445
    Display images for AppID 2133445


    .DESCRIPTION
    A function to find images for a nominated app and show some interesting fields

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
    
    if (!($appid))
    {
        [string]$appid = Read-Host "AppID"
    }
         
    $output = Get-AGMImage -filtervalue appid=$appid -sort "jobclasscode:asc,consistencydate:asc"
    if ($output.id)
    {
        $backup = Foreach ($id in $output)
        { 
            $id | select-object backupname, jobclass, consistencydate, endpit 
        }
        $backup
    }
    else
    {
        $output
    }
}