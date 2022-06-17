# Copyright 2022 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Export-AGMLibSLT
            Read-Host -Prompt "Press enter to continue"
            onpremisesactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            onpremisesactions
        }
        else 
        {
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
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Import-AGMLibSLT
            Read-Host -Prompt "Press enter to continue"
            onpremisesactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            onpremisesactions
        }
        else 
        {
            return    
        }
    }
    function importagmsltsgc
    {
        Clear-Host
        Write-Host "Import AGM SLTs"  
        Write-Host ""
        Write-Host "The function you need to run is:   Import-AGMLibSLT"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Import-AGMLibSLT
            Read-Host -Prompt "Press enter to continue"
            gcpactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcpactions
        }
        else 
        {
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
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Get-AGMLibSLA
            Read-Host -Prompt "Press enter to continue"
            onpremisesactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            onpremisesactions
        }
        else 
        {
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
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Set-AGMLibSLA
            Read-Host -Prompt "Press enter to continue"
            onpremisesactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            onpremisesactions
        }
        else 
        {
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
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Import-AGMLibOnVault
            gcpactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcpactions
        }
        else 
        {
            return    
        }
    }
    function createhostlist
    {
        Clear-Host
        Write-Host "Create a host list"
        Write-Host ""
        Write-Host "The function you need to run is:   Get-AGMLibHostList"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Get-AGMLibHostList
            Read-Host -Prompt "Press enter to continue"
            gcpactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcpactions
        }
        else 
        {
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
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Get-AGMLibImageRange
            Read-Host -Prompt "Press enter to continue"
            gcpactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcpactions
        }
        else 
        {
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
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            New-AGMLibMultiMount
            Read-Host -Prompt "Press enter to continue"
            gcpactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcpactions
        }
        else 
        {
            return    
        }
   }

   function listmounts
   {
        Clear-Host
        Write-Host "List your mounts"
        Write-Host ""
        Write-Host "The function you need to run is:   Get-AGMLibActiveImage"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Get-AGMLibActiveImage | Select-Object id,imagename,apptype,appliancename,hostname,appname,mountedhost,consumedsize_gib,label,imagestate | Format-Table
            Read-Host -Prompt "Press enter to continue"
            gcpactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcpactions
        }
        else 
        {
            return    
        }
   }

   function  monitormounts

   {
        Clear-Host
        Write-Host "Monitor your mounts"
        Write-Host ""
        Write-Host "The function you need to run is:    Get-AGMLibRunningJobs -jobclass mount -m"
        Write-Host ""
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Get-AGMLibRunningJobs -jobclass mount -m
            gcpactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcpactions
        }
        else 
        {
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
        Write-Host "1`: Run it now (default)"
        Write-Host "2`: Take me back to the previous menu"
        Write-Host "3`: Exit, I will run this later "
        [int]$userselection1 = Read-Host "Please select from this list [1-3]"
        if ($userselection1 -eq 1 -or $userselection1 -eq "")
        {
            Remove-AGMLibMount
            Read-Host -Prompt "Press enter to continue"
            gcpactions
        } 
        elseif  ($userselection1 -eq 2) 
        {
            gcpactions
        }
        else 
        {
            return    
        }
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
        Write-Host ""
        Write-host "Production site actions for ransomware protection"
        write-host ""    
        Write-host "Note that if you have not connected to AGM yet with Connect-AGM, then do this first before proceeding"
        Write-Host "What do you need to do?"
        Write-Host ""
        write-host "1`: Login to AGM            Do you need to login to AGM with Connect-AGM?"
        write-host "2`: Export AGM SLTs         Do you want to export your Policy Templates from AGM?"
        write-host "3`: Import AGM SLTs         Do you want to import Policy Templates into a new AGM?"
        Write-Host "4`: Check the scheduler     Do you want to check if the scheduler is enabled?"
        Write-Host "5`: Set the scheduler       Do you want to change the scheduler or expiration right now?  For instance to stop new backups being created."
        write-host "6`: Back                    Take me back to the previous menu"
        write-host "7`: Exit                    Take me back to the command line"
        Write-Host ""
        # ask the user to choose
        While ($true) 
        {
            Write-host ""
            $listmax = 7
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
        if ($userselection1 -eq 6) { mainmenu }  
        if ($userselection1 -eq 7) { return }     
   }
   function gcpactions
   {  
        Write-Host ""
        Write-host "DR Site actions for ransomware recovery"
        Write-Host ""
        Write-host "Note that if you have not connected to AGM yet with Connect-AGM, then do this first before proceeding"
        Write-Host "What do you need to do?"
        Write-Host ""
        write-host " 1`: Login to AGM            Do you need to login to AGM with Connect-AGM?"
        write-host " 2`: Import AGM SLTs         Do you want to import Policy Templates from the source AGM?  Note you need to have a file of exported SLTs to do this"
        write-host " 3`: Import OnVault images   Do you want to import (or forget) the latest images from an OnVault pool so they can be used in the DR Site?"
        Write-Host " 4`: Create an image list    Do you want to create a list of images that you could use to identify which backups to use?"
        Write-Host " 5`: Create a host list      Do you want to create a list of hosts that you will mount your backups to ?"
        Write-Host " 6`: Mount your image list   Do you have a list of backups (from step 4) and you want to mount all of them at once?"
        Write-Host " 7`: Monitor your mounts     Do you want to monitor running mount jobs"
        Write-Host " 8`: List your mounts        Do you want to list the current mounts"
        Write-Host " 9`: Unmount your images     Do you want to unmount the images we mounted in step 6"
        write-host "10`: Set image labels        Do you want to apply a label to an image or images to better tag that image?"
        write-host "11`: Back                    Take me back to the previous menu"
        write-host "12`: Exit                    Take me back to the command line"
        Write-Host ""
        # ask the user to choose
        While ($true) 
        {
            Write-host ""
            $listmax = 12
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
        if ($userselection2 -eq 2) { importagmsltsgc }
        if ($userselection2 -eq 3) { importonvaultimages }
        if ($userselection2 -eq 4) { createimagelist }
        if ($userselection2 -eq 5) { createhostlist }
        if ($userselection2 -eq 6) { mountyourimagelist }
        if ($userselection2 -eq 7) { monitormounts }
        if ($userselection2 -eq 8) { listmounts }
        if ($userselection2 -eq 9) { unmountyourimages }
        if ($userselection2 -eq 10) { setimagelabels }
        if ($userselection2 -eq 11) { mainmenu }  
        if ($userselection2 -eq 12) { return }

    }

    function mainmenu
    {
        $sessiontest = Get-AGMVersion

        
        clear-host
        Write-Host "This function is designed to help you learn which functions to run before or during a ransomware attack."
        Write-Host ""
        Write-host "We are either running this from the Production site or the DR Site."
        Write-Host "Which site are you working with?"
        Write-Host ""
        write-host "1`: Production Site"
        Write-Host "2`: DR Site"
        if ($sessiontest.errormessage)
        {
            Write-Host ""
            Write-Host "**** NOTE!   You are not logged into AGM, so please do that first ****"
        }
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
    mainmenu
}