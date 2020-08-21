Function Get-AGMLibRunningJobs 
{
    <#
    .SYNOPSIS
    Displays all running jobs

    .EXAMPLE
    Get-AGMLibRunningJobs
    Displays all running jobs

    .DESCRIPTION
    A function to find running jobs

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

    $fv = "status=running"
       
    $outputgrab = Get-AGMJob -filtervalue "$fv" 
    if ($outputgrab.id)
    {
        $AGMArray = @()

        Foreach ($id in $outputgrab)
        { 
            $id | Add-Member -NotePropertyName appliancename -NotePropertyValue $id.appliance.name
            $AGMArray += [pscustomobject]@{
                jobname = $id.jobname
                jobclass = $id.jobclass
                apptype = $id.apptype
                hostname = $id.hostname
                appname = $id.appname
                appid = $id.appid
                appliancename = $id.appliancename
                startdate = $id.startdate
                progress = $id.progress
                targethost = $id.targethost
                duration = Convert-AGMDuration $id.duration
            }
        }
        $AGMArray 
    }
    else
    {
        $outputgrab
    }
}