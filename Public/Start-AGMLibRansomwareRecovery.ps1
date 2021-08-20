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
   
    function loginonprem
    {  
         Connect-AGM
         onpremisesactions
    }
    function logingcp
    {  
         Connect-AGM
         gcpactions
    }

    function exportagmslts
    {
        Clear-Host
        Write-Host "Export AGM SLTs"  
        Write-Host ""
        Write-Host "The function you need to run is:   Export-AGMLibSLT"
        Write-Host ""
        Write-Host "1`: Exit, I will run it later (default)"
        Write-Host "2`: Run it now"
        [int]$userselection1 = Read-Host "Please select from this list [1-2]"
        if ($userselection1 -eq 2)
        {
            Clear-Host
            Export-AGMLibSLT
            Read-Host -Prompt "Press enter to continue"
            onpremisesactions
        } else {
            return
        }
    }

    function importagmslts
    {
        Clear-Host
        Write-Host "Import AGM SLTs"  
        Write-Host ""
        Write-Host "The function you need to run is:   Import-AGMLibSLT"
        Write-Host ""
        Write-Host "1`: Exit, I will run it later (default)"
        Write-Host "2`: Run it now"
        [int]$userselection1 = Read-Host "Please select from this list [1-2]"
        if ($userselection1 -eq 2)
        {
            Clear-Host
            Import-AGMLibSLT
            Read-Host -Prompt "Press enter to continue"
            onpremisesactions
        } else {
            return
        }
    }
    function schedulercheck
   {  
        Clear-Host
        Write-Host "Check the scheduler"  
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
            Read-Host -Prompt "Press enter to continue"
            onpremisesactions
        } else {
            return
        }
    
   }
   function stopnewbackup
   {  
        Clear-Host
        Write-Host "Stop new backups"
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
            onpremisesactions
        } else {
            return
        }

   }

    function importonvaultimages
    {
        Clear-Host
        Write-Host "Import OnVault Images"
        Write-Host ""
        Write-Host "The function you need to run is:   Import-AGMLibOnVault"
        Write-Host ""
        Write-Host "1`: Exit, I will run it later (default)"
        Write-Host "2`: Run it now"
        [int]$userselection2 = Read-Host "Please select from this list [1-2]"
        if ($userselection2 -eq 2)
        {
            Import-AGMLibOnVault
            Read-Host -Prompt "Press enter to continue"
            gcpactions
        } else {
            return
        }
    }
   function createimagelist
   {  
        Clear-Host
        Write-Host "Create an image list"
        Write-Host ""
        Write-Host "The function you need to run is:   Get-AGMLibImageRange"
        Write-Host ""
        Write-Host "1`: Exit, I will run it later (default)"
        Write-Host "2`: Run it now"
        [int]$userselection2 = Read-Host "Please select from this list [1-2]"
        if ($userselection2 -eq 2)
        {
            Get-AGMLibImageRange
            Read-Host -Prompt "Press enter to continue"
            gcpactions
        } else {
            return
        }
   }
   function mountyourimagelist 
   {  
        Clear-Host
        Write-Host "Mount your image list"
        Write-Host ""
        Write-Host "The function you need to run is:   New-AGMLibMultiMount"
        Write-Host ""
        Write-Host "1`: Exit, I will run it later (default)"
        Write-Host "2`: Run it now"
        [int]$userselection2 = Read-Host "Please select from this list [1-2]"
        if ($userselection2 -eq 2)
        {
            New-AGMLibMultiMount

        } else {
            return
        }
   }
   function unmountyourimages
   {  
        Clear-Host
        Write-Host "Unmount your images"
        Write-Host ""
        Write-Host "The function you need to run is:   Remove-AGMLibMount"
        Write-Host ""
        Write-Host "1`: Exit, I will run this later (default)"
        Write-Host "2`: Guide me now"
        [int]$userselection2 = Read-Host "Please select from this list [1-2]"
        if ($userselection2 -ne 2)
        {
            return
        }
        Remove-AGMLibMount
   }    

   function setimagelabels
   {  
        Clear-Host
        write-host "Set image labels"
        Write-Host ""
        Write-Host "The function you need to run is:   Set-AGMLibImage"
        Write-Host "This function is used to label a large number of images in a single command.  This is done by supplying one of the following:
-- A list of images to label, normally created with New-AGMLibImageRange.  We then use -imagelist <imagelist>
-- A CSV file contained a list of images with new labels.  The file needs to have at least id,backupname,label as headings.  You could use New-AGMLibImageRange to create this file.  Then use:  -filename <filename.csv>
-- An imagename.   You could learn this in the AGM Web GUI.   Then use:  -imagename <imagename> -label <newlabel>"
   }


   
   function onpremisesactions
   {  
        clear-host
        Write-host "On-premises actions for ransomware protection"
        write-host ""    
        Write-host "Note that if you have not connected to AGM yet with Connect-AGM, then do this first before proceeding"
        Write-Host "What do you need to do?"
        Write-Host ""
        write-host "1`: Login to AGM            Do you need to login to AGM with Connect-AGM?"
        write-host "2`: Export AGM SLTs         Do you want to export your Policy Templates from AGM?"
        write-host "3`: Import AGM SLTs         Do you want to import Policy Templates into a new AGM?"
        Write-Host "4`: Check the scheduler     Do you want to check if the scheduler is enabled?"
        Write-Host "5`: Stop new backups        Do you want to stop the scheduler or expiration right now?  This is to stop new backups being created."
        write-host "6`: Exit"
        Write-Host ""
        # ask the user to choose
        While ($true) 
        {
            Write-host ""
            $listmax = 6
            [int]$userselection1 = Read-Host "Please select from this list [1-$listmax]"
            if ($userselection1 -lt 1 -or $userselection1 -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
            } 
            else
            {
                break
            }
        }
        if ($userselection1 -eq 1) { loginonprem }
        if ($userselection1 -eq 2) { exportagmslts }
        if ($userselection1 -eq 3) { importagmslts }
        if ($userselection1 -eq 4) { schedulercheck }    
        if ($userselection1 -eq 5) { stopnewbackup }  
        if ($userselection1 -eq 6) { return }     
   }
   function gcpactions
   {  
        clear-host
        Write-host "Google Cloud Platorm actions for ransomware protection"
        Write-Host ""
        Write-host "Note that if you have not connected to AGM yet with Connect-AGM, then do this first before proceeding"
        Write-Host "What do you need to do?"
        Write-Host ""
        write-host "1`: Login to AGM            Do you need to login to AGM with Connect-AGM?"
        write-host "2`: Import OnVault images   Do you want to import (or forget) the latest images from an OnVault pool so they can be used in GCP?"
        Write-Host "3`: Create an image list    Do you want to create a list of images that you could use to identify which backups to use?"
        Write-Host "4`: Mount your image list   Do you have a list of backups (from step 4) and you want to mount all of them at once?"
        Write-Host "5`: Unmount your images     Do you want to unmount the images we mounted in step 5"
        write-host "6`: Set image labels        Do you want to apply a label to an image or images to better tag that image?"
        write-host "7`: Exit"
        Write-Host ""
        # ask the user to choose
        While ($true) 
        {
            Write-host ""
            $listmax = 7
            [int]$userselection2 = Read-Host "Please select from this list [1-$listmax]"
            if ($userselection2 -lt 1 -or $userselection2 -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
            } 
            else
            {
                break
            }
        }
        if ($userselection2 -eq 1) { logingcp }
        if ($userselection2 -eq 2) { importonvaultimages }
        if ($userselection2 -eq 3) { createimagelist }
        if ($userselection2 -eq 4) { mountyourimagelist }
        if ($userselection2 -eq 5) { unmountyourimages }
        if ($userselection2 -eq 6) { setimagelabels }
        if ($userselection2 -eq 7) { return }

    }

    Clear-Host
    Write-Host "This function is designed to help you learn which functions to run before or during a ransomware attack."
    Write-Host ""
    Write-host "We are either running this from On-Premises or in the Google Cloud."
    Write-Host "Which site are you working with?"
    Write-Host ""
    write-host "1`: On-premises"
    Write-Host "2`: Google Cloud"
    while ($true) 
    {
        Write-host ""
        $listmax = 2
        [int]$siteselection = Read-Host "Please select from this list [1-$listmax]"
        if ($siteselection -lt 1 -or $siteselection -gt $listmax)
        {
            Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
        } 
        else
        {
            break
        }
    }
    if ($siteselection -eq 1) { onpremisesactions } 
    if ($siteselection -eq 2) { gcpactions }
}