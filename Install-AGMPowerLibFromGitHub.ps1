# 
## File: Install-AGMpowerLibFromGitHub.ps1
## Purpose: Script to automate the installation of AGMPowerLib
#
# Version 1.0 Initial Release

#

<#   
.SYNOPSIS   
   Download and install AGMPowerLib
.DESCRIPTION 
   This is a powershell script that helps you auomate the process of installing AGMPowerLib modules from the Actifio github site. It can automate the download and installation process.
.PARAMETER action
    To enable the download of AGMPowerLib software, use -download. To install it, use the -install switch. Use the -TmpDir directory if you want to specify a working temporary directory for the zipped file.
.EXAMPLE
    PS > .\Install-AGMpowerLibFromGitHub.ps1 -download -install
    To download and install the ActPowerCLI
.EXAMPLE
    PS > .\Install-AGMpowerLibFromGitHub.ps1 -download 
    To download the ActPowerCLI modules
.EXAMPLE 
    PS > .\Install-AGMpowerLibFromGitHub.ps1 -install -TmpDir c:\temp
    To install the ActPowerCLI modules using the zip file c:\temp
.NOTES   
    Name: Install-AGMpowerLibFromGitHub.ps1
    Author: Anthony Vandewerdt
    DateCreated: 05-Sept-2020
    LastUpdated: 06-Sept-2020
.LINK
    https://github.com/Actifio   
#>

param([switch][alias("d")]$download,[switch][alias("i")]$install,[string]$TmpDir,[string]$branch)


function Get-AGMPowerLib (
      [string]$Software )
{
    Write-Host "Downloading AGMPowerLib."

    if (!($branch))
    {
        $branch = "main"
    }
    $url = " https://github.com/Actifio/AGMPowerLib/archive/" + $branch + ".zip"
    $platform=$PSVersionTable.platform
    if ( $platform -match "Unix" )
    {
        $download_path = "$TmpDir" + $Software 
    }
    else 
    {
        $download_path = "$TmpDir\" + $Software 
    }

    Write-Host "Downloading latest version of AGMPowerLib from $branch branch using $url to $download_path" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $download_path

    Write-Host "File saved to $download_path" -ForegroundColor Green

    Write-Host "Unblocking the downloaded file - $url" -ForegroundColor Cyan
    Get-Item $download_path | Unblock-File

}

##################################
# Function: Install-AGMPowerLib
#
##################################
function Install-AGMPowerLib ( [string]$Software )
{
    $platform=$PSVersionTable.platform
    $modulebase = (get-module -listavailable -name AGMPowerLib).modulebase
    if ($modulebase) 
    {
        Write-Host "`nAGMPowerLib Module already installed in:"
        foreach ($base in $modulebase)
        {
            write-host "    $base"
        }
    }

    if (!($modulebase))
    {
        $platform=$PSVersionTable.platform
        if ( $platform -match "Unix" )
        {
            $targetondisk = "$($env:PSModulePath.Split(':')[0])" + "/" + "AGMPowerLib"
        }
        else 
        {
            $targetondisk = "$($env:SystemDrive)\Program Files\PowerShell\Modules\AGMPowerLib"
        }

        Write-Host "`nInstalling AGMPowerLib to $targetondisk`n"

    }
    else 
    {
        Write-Host "`nUpgrading AGMPowerLib"
        Uninstall-Module -Name AGMPowerLib -ErrorAction SilentlyContinue
        Remove-Module -Name AGMPowerLib -ErrorAction SilentlyContinue
    }

    $download_path = "$TmpDir" + "/" + $branch + ".zip" 
    #
    # Copies the module to the appropriate directory and cleanup the folders
    #
    $unziptarget = "$TmpDir" + "\ActDownload"
    Expand-Archive -Path $download_path -DestinationPath $unziptarget -Force



    Write-Host "Copying files" -ForegroundColor Cyan

    if (!($modulebase))
    {
        if ( $platform -match "Unix" )
        {
            $WorkDir = $TmpDir + "/ActDownload/AGMPowerLib-" + $branch
        }
        else 
        {
            $WorkDir = $TmpDir + "\ActDownload\AGMPowerLib-" + $branch
        }
        $null = New-Item -ItemType Directory -Path $targetondisk -Force -ErrorAction Stop
        if ( $platform -match "Unix" )
        {
            $null = Copy-Item $WorkDir/* $targetondisk -Force -Recurse -ErrorAction Stop
        }
        else 
        {
            $null = Copy-Item $WorkDir\* $targetondisk -Force -Recurse -ErrorAction Stop
        }
        $null = Test-Path -Path $targetondisk -ErrorAction Stop
        Write-Host "Module has been installed" -ForegroundColor Green
    }
    else 
    {
        foreach ($base in $modulebase)
        {
            Write-host "Upgrading $base"
            if ( $platform -match "Unix" )
            {
                $WorkDir = $TmpDir + "/ActDownload/AGMPowerLib-" + $branch
                $null = Copy-Item $WorkDir/AGMPowerLib* $base -Force -Recurse -ErrorAction Stop
            }
            else 
            {
                $WorkDir = $TmpDir + "\ActDownload\AGMPowerLib-" + $branch
                $null = Copy-Item $WorkDir\AGMPowerLib* $base -Force -Recurse -ErrorAction Stop
            }
            $null = Test-Path -Path $base -ErrorAction Stop
            Write-Host "Module has been upgraded" -ForegroundColor Green
        }
        
    }


    if ( $platform -match "Unix" )
    {
        Remove-Item -Recurse -Path ($TmpDir + "/ActDownload") -force
    }    
    else 
    {
        Remove-Item -Recurse -Path ($TmpDir + "\ActDownload") 
    }
        
    
    Remove-Item -Path ($download_path) -Force


    # 
    # Install the AGMPowerLib module
    #
    Import-Module -Name AGMPowerLib
    Get-Command -Module AGMPowerLib

    # Get-Module ActPowerCLI -ListAvailable | Remove-Module
    # Get-Module AGMPowerLib -ListAvailable
    # Remove-Module -Name ActPowerCLI -Force
}


##############################
#
#  M A I N    B O D Y
#
##############################

if ($download -eq $false -And $install -eq $false) {
    Clear-Host
    Write-host "AGMPowerLib Download decision"
    Write-Host ""
    Write-Host "1`: Download from Main (default)"
    Write-Host "2`: Download from another branch"
    Write-Host "3`: Don't download"
    Write-Host ""
    [int]$userselection = Read-Host "Please select from this list (1-3)"
    if ($userselection -eq "") { $userselection = 3 }
    if ($userselection -eq 1) {  $branch = "main" ; $download = $TRUE }
    if ($userselection -eq 2) 
    {  
        Write-Host ""
        [string]$branch = Read-Host "Branch to download from (default is main)"
        $download = $TRUE 
    }
    Write-Host "Install after download?"
    Write-Host "1`: Install after download (Default)"
    Write-Host "2`: Don't install"
    Write-Host ""
    [int]$userselection = Read-Host "Please select from this list (1-2)"
    if ($userselection -eq "") { $userselection = 1 }
    if ($userselection -eq 1) {  $install = $TRUE }
}

if ($TmpDir -eq $null -or $TmpDir -eq "") 
{
    $platform=$PSVersionTable.platform
    if ( $platform -match "Unix" )
    {
        $TmpDir = '~/Downloads/'
    }
    else 
    {
        $TmpDir = $($env:TEMP)        
    }
}

if ($branch -eq "") { $branch = "main" }
$Software = $branch + ".zip"

if ($download) {
  Get-AGMPowerLib $Software
}

$platform=$PSVersionTable.platform

if ($install) {
  $PSversion = $($host.version).major
  if ($PSversion -lt 7) {
    Write-Host "The minimal version of PowerShell for AGMPowerLib is 7.0 and above. Current version is $PSVersion ."
    Write-Host "Will not install AGMPowerLib. "
    exit
  } 
  Install-AGMPowerLib $Software
}

exit