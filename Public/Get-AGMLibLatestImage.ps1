Function Get-AGMLibLatestImage([int]$id, [string]$jobclass) 
{
    <#
    .SYNOPSIS
    Displays the most recent image for an application

    .EXAMPLE
    Get-AGMLatestImage
    You will be prompted for application ID 

    .EXAMPLE
    Get-AGMLatestImage -id 4771
    Get the last snapshot created for the application with ID 4771

    .EXAMPLE
    Get-AGMLatestImage -id 4771 -jobclass dedup
    Get the last dedup created for the application with ID 4771


    .DESCRIPTION
    A function to find the latest image created for an application
    By default you will get the latest snapshot image

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
    
    if (!($id))
    {
        [int]$id = Read-Host "ID"
    }
      
    if ($jobclass)
    {
        $fv = "appid=" + $id + "&jobclass=$jobclass"
    }
    else 
    {
        $fv = "appid=" + $id + "&jobclass=snapshot"
    }
    
    $backup = Get-AGMImage -filtervalue "$fv" -sort ConsistencyDate:desc -limit 1
    if ($backup.id)
    {
        $backup | Add-Member -NotePropertyName appid -NotePropertyValue $backup.application.id
        $backup | Add-Member -NotePropertyName appliance -NotePropertyValue $backup.cluster.name
        $backup | Add-Member -NotePropertyName hostname -NotePropertyValue $backup.host.hostname
        $backup | Select-Object appliance, hostname, appname, appid, jobclass, backupname, id, consistencydate, endpit, sltname, slpname, policyname
    }
    else
    {
        $backup
    }
}