function Start-AGMLibRansomwareRecovery
{

    <#
    .SYNOPSIS
   Guided menu to help user with finding right functions to handle ransomware attack

    .EXAMPLE
    Start-AGMLibRansomwareRecovery
    Runs a guided menu 
    

    .DESCRIPTION
    A function to help users find the right commands to run
    #>

   #
   

    Write-Host "This function is designed to help you learn which functions to run during a ransomware attack."
    Write-host "Note that if you have not connected to AGM yet with Connect-AGM, then do this first before proceeding"
    Write-Host "What do you need to do?"
    Write-Host ""
    write-host "1`: Login to AGM            Do you need to login to AGM with Connect-AGM?"
    Write-Host "2`: Check the scheduler     Do you want to check if the scheduler is enabled?"
    Write-Host "3`: Stop new backups        Do you want to stop the scheduler or expiration right now?  This is to stop new backups being created."
    Write-Host "4`: Mount one image         Do you want to run mount jobs one at a time to find good images?"
    Write-Host "5`: Create an image list    Do you want to create a list of images that you could use to identify which backups to use?"
    Write-Host "6`: Mount your image list   Do you have a list of backups (from step 4) and you want to mount all of them at once?"
    write-host "7`: Set image labels        Do you want to apply a label to an image or images to better tag that image?"
    write-host "8`: Exit"
    Write-Host ""
    # ask the user to choose
    While ($true) 
    {
        Write-host ""
        $listmax = 8
        [int]$userselection = Read-Host "Please select from this list [1-$listmax]"
        if ($userselection -lt 1 -or $userselection -gt $listmax)
        {
            Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
        } 
        else
        {
            break
        }
    }
    if ($userselection -eq 1) 
    {  
         Connect-AGM
         Start-AGMLibRansomwareRecovery
    }

   if ($userselection -eq 2) 
   {  
        Clear-Host
        Write-Host "2`: Check the scheduler"  
        Write-Host ""
        Write-Host "The function you need to run is:   Get-AGMLibSLA"
        Write-Host ""
        Write-Host "1`: Exit, I will run it later (default)"
        Write-Host "2`: Run it now"
        [int]$userselection1 = Read-Host "Please select from this list [1-2]"
        if ($userselection1 -eq 2)
        {
            Clear-Host
            Get-AGMLibSLA
            Start-AGMLibRansomwareRecovery
        } else {
            return
        }
    
   }
   if ($userselection -eq 3) 
   {  
        Clear-Host
        Write-Host "3`: Stop new backups"
        Write-Host ""
        Write-Host "The function you need to run is:   Set-AGMLibSLA"
        Write-Host ""
        Write-Host "1`: Exit, I will run it later (default)"
        Write-Host "2`: Run it now"
        [int]$userselection2 = Read-Host "Please select from this list [1-2]"
        if ($userselection2 -eq 2)
        {
            Clear-Host
            Set-AGMLibSLA
            Start-AGMLibRansomwareRecovery
        } else {
            return
        }

   }
   if ($userselection -eq 4) 
   {  
        Clear-Host
        Write-Host "4`: Mount one image"
        Write-Host ""
        Write-Host "There are several functions to run mounts depending on Application type:"
        write-host ""
        Write-host "FileSystems:      New-AGMLibFSMount"
        Write-host "MS SQLServer DB:  New-AGMLibMSSQLMount"
        Write-host "Oracle DB:        New-AGMLibOracleMount"
        Write-host "VMware VM:        New-AGMLibVM"
   }
   if ($userselection -eq 5) 
   {  
        Clear-Host
        Write-Host "5`: Create an image list"
        Write-Host ""
        Write-Host "The function you need to run is:   Get-AGMLibImageRange"
        Write-Host "The help can be read by using:     Get-Help Get-AGMLibImageRange -detailed"
        Write-host "First read the help and then run the function.   You got here by choosing option 4.  Once you have the image list, come back and choose option 5."

   }
   if ($userselection -eq 6) 
   {  
        Clear-Host
        Write-Host "6`: Mount your image list"
        Write-Host ""
        Write-Host "The function you need to run is:   New-AGMLibMultiMount"
        Write-Host "The help can be read by using:     Get-Help New-AGMLibMultiMount -detailed"

   }

   if ($userselection -eq 7) 
   {  
        Clear-Host
        write-host "7`: Set image labels"
        Write-Host ""
        Write-Host "The function you need to run is:   Set-AGMLibImage"
        Write-Host "The help can be read by using:     Get-Help Set-AGMLibImage -detailed"

   }

   if ($userselection -eq 8) 
   {  
        Return
   }
}