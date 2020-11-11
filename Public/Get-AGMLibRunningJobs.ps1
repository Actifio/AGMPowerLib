Function Get-AGMLibRunningJobs  ([switch][alias("e")]$every,[switch][alias("q")]$queue)
{
    <#
    .SYNOPSIS
    Displays all running jobs

    .EXAMPLE
    Get-AGMLibRunningJobs
    Displays all running jobs

    .EXAMPLE
    Get-AGMLibRunningJobs -e
    Displays all queued or running jobs

    .EXAMPLE
    Get-AGMLibRunningJobs -q
    Displays all queued jobs

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
    if ($queue)
    {
        $outputgrab = Get-AGMJob | where-object { $_.status -like "queued" } 
    }       
    elseif ($every)
    {
        $outputgrab = Get-AGMJob 
    }
    else 
    {
        $outputgrab = Get-AGMJob -filtervalue "status=running" 
    }
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
                status = $id.status
                queuedate = $id.queuedate
                startdate = $id.startdate
                progress = $id.progress
                targethost = $id.targethost
                duration = $id.duration
            }
        }
        $AGMArray 
    }
    else
    {
        $outputgrab
    }
}