Function Get-AGMLibFollowJobStatus ([string]$jobname) 
{
    <#
    .SYNOPSIS
    Tracks job status for a nominated job

    .EXAMPLE
    Get-AGMLibFollowJobStatus
    You will be prompted for a JobName

    .EXAMPLE
    Get-AGMLibFollowJobStatus Job_1234
    Tracks the progress of Job_1234 to conclusion.   Tracking will stop when the job completes, is canceled or fails.


    .DESCRIPTION
    A function to follow the progress with 5 second intervals until the job succeeds or is not longer running or queued

    #>


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
    

    if (!($jobname))
    {
        $jobname = Read-Host "JobName"
    }
    
    $done = 0
    do 
    {
        $jobgrab = Get-AGMJobStatus -filtervalue jobname=$jobname
        if ($jobgrab.errormessage)
        {   
            $done = 1
            $jobgrab
        }    
        elseif (!($jobgrab.status)) 
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $jobname"
            $done = 1
        }
        elseif ($jobgrab.status -like "queued")
        {
            $jobgrab | select-object jobname, status, queuedate, targethost | Format-Table
            Start-Sleep -s 5
        }
        elseif ($jobgrab.status -like "initializing")
        {
            $jobgrab | select-object jobname, status, queuedate, targethost | Format-Table
            Start-Sleep -s 5
        }
        elseif ($jobgrab.status -like "running") 
        {
            $jobgrab | select-object jobname, status, progress, queuedate, startdate, duration, targethost | Format-Table
            Start-Sleep -s 5
        }
        else 
        {
            $jobgrab | select-object jobname, status, message, startdate, enddate, duration, targethost
            $done = 1    
        }
    } until ($done -eq 1)
}