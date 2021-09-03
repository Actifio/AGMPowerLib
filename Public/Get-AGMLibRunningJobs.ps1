Function Get-AGMLibRunningJobs  ([switch][alias("e")]$every,[switch][alias("q")]$queue,[string]$jobclass,[string]$sltname,[switch][alias("m")]$monitor)
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
    By default it will only show running jobs
    -queue will show only queued jobs
    -every will show eery job
    -sltname will filter on template name
    -jobclass will filter on jobclass.   Multiple jobclasses can be entered comma separated
    -monitor will run the function continuously checking every 10 seconds

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    $sessiontest = Get-AGMVersion
    if ($sessiontest.errormessage)
    {
        Get-AGMErrorMessage -messagetoprint "AGM session has expired. Please login again using Connect-AGM"
        return
    }

    $fv = "&status=running"
    if ($queue)
    {
        $fv = "&status=queued"
    }
    if ($every)
    {
        $fv = "&"
    }
    # we allow filtering on temp
    if ($sltname)
    {
        $fv = $fv + "&sltname=" + $sltname
    }
    if ($jobclass)
    {
        foreach ($class in $jobclass.split[","])
        {
            $fv = $fv + "&jobclass=" +$class
        }
    }
    # get rid of the leading &
    $fv = $fv.Substring(1)

    
    if ($monitor)
    {
        $done = 0
        do 
        {
            Clear-Host
            $outputgrab = Get-AGMJob -filtervalue $fv
  
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
            $AGMArray | select-object jobname,jobclass,hostname,appname,appliancename,status,startdate,progress,targethost,duration  | Format-Table
            

            write-host ""
            $n=10
            do
            {
            Write-Host -NoNewLine "`rRefreshing in $n "
            start-Sleep -s 1
            $n = $n-1
            } until ($n -eq 0)
            
        } until ($done -eq 1)
    } 
    else 
    {   
        $outputgrab = Get-AGMJob -filtervalue $fv
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
    
}