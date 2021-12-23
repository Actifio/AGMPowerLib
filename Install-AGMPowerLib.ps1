function GetAGMPowerLibInstall 
{
  # Returns the known installation locations for the AGMPowerLib Module
  return Get-Module -ListAvailable -Name AGMPowerLib -ErrorAction SilentlyContinue | Select-Object -Property Name, Version, ModuleBase
}

function GetPSModulePath 
{
    # Returns all available PowerShell Module paths  
    # Windows uses semi-colons, Linux and Mac use colons, go figure.
    $platform=$PSVersionTable.platform
	if ( $platform -match "Unix" )
	{
		return $env:PSModulePath.Split(':')
    }
    else 
    {
      $hostVersionInfo = (get-host).Version.Major
      if ( $hostVersionInfo -lt "6" )
      {
        return $env:PSModulePath.Split(';') 
      }
      else 
      {
        return $env:PSModulePath.Split(';') -notmatch "WindowsPowerShell"
      }
    }
}

function InstallMenu 
{
  # Creates a menu of available install or upgrade locations for the module
  Param(
    [Array]$InstallPathList,
    [ValidateSet('installation','upgrade or delete')]
    [String]$InstallAction
  )
  $i = 1
  foreach ($Location in $InstallPathList)
  {
    Write-Host -Object "$i`: $Location"
    $i++
  }

  While ($true) 
  {
    [int]$LocationSelection = Read-Host -Prompt "`nPlease select an $InstallAction path"
    if ($LocationSelection -lt 1 -or $LocationSelection -gt $InstallPathList.Length)
    {
      Write-Host -Object "Invalid selection. Please enter a number in range [1-$($InstallPathList.Length)]"
    } 
    else
    {
      break
    }
  }
  
  return $InstallPathList[($LocationSelection - 1)]
}

function RemoveModuleContent 
{
  # Attempts to remove contents from an existing installation
  try 
  {
    Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop -Confirm:$true
  }
  catch 
  {
    throw "$($_.ErrorDetails)"
  }
}

function CreateModuleContent
{
  # Attempts to create a new folder and copy over the AGMPowerLib Module contents
  try
  { 
    $platform=$PSVersionTable.platform
    if ( $platform -notmatch "Unix" )
    {
      $null = Get-ChildItem -Path $PSScriptRoot\* -Recurse | Unblock-File
    }
    $null = New-Item -ItemType Directory -Path $InstallPath -Force -ErrorAction Stop
    $null = Copy-Item $PSScriptRoot\* $InstallPath -Force -Recurse -ErrorAction Stop
    $null = Test-Path -Path $InstallPath -ErrorAction Stop
    $commandcheck = get-command -module AGMPowerLib
    if (!($commandcheck))
    {
      Write-Host -Object "`nInstallation failed."
    }
    else {
      Write-Host -Object "`nInstallation successful."
    }
  }
  catch 
  {
    throw $_
  }
}

function ReportAGMPowerLib
{
  # Removes the AGMPowerLib Module from the active session and displays a list of all current install locations
  Remove-Module -Name AGMPowerLib -ErrorAction SilentlyContinue
  GetAGMPowerLibInstall
}

### Code
$hostVersionInfo = (get-host).Version.Major
if ( $hostVersionInfo -lt "5" )
{
    Write-Host "This module only works with PowerShell Version 5.  You are running version $hostVersionInfo."
    Write-Host "You will need to install PowerShell Version 5 or higher and try again"
    break
}

$commandcheck = get-command -module AGMPowerCLI
if (!($commandcheck))
{
  Write-Host -Object "`nAGMPowerCLI not installed.  Install this first"
  Write-Host ""
  exit
}

Import-LocalizedData -BaseDirectory $PSScriptRoot\ -FileName AGMPowerLib.psd1 -BindingVariable ActModuleData

function silentinstall0
{
  Write-host 'Detected PowerShell version:   ' $hostVersionInfo
  Write-host 'Downloaded AGMPowerLib version:' $ActModuleData.ModuleVersion
  $platform=$PSVersionTable.platform
  # if we find an install then we upgrade it
  [Array]$ActInstall = GetAGMPowerLibInstall
  if ($ActInstall.name.count -gt 1)
  {
    Write-Host -Object "`nMultiple installations detected.  Silent Installation failed."
  }
  # if it is installed, uninstall it, but keep the install path to re-use, otherwise use the second module path by default
  if ($ActInstall.name.count -eq 1)
  {
    $InstallPath = $ActInstall.ModuleBase
    Write-host 'Found AGMPowerLib version:     ' $ActInstall.Version 'in ' $InstallPath 
    Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop -Confirm:$false
  }
  else 
  {
    $InstallPathList = GetPSModulePath
    $InstallPath = $InstallPathList[0]
    if ( $platform -notmatch "Unix" )
    {
      $InstallPath = $InstallPath + '\AGMPowerLib\'
    }
    else 
    {
      $InstallPath = $InstallPath + '/AGMPowerLib/'
    }
  }  
  if ( $platform -notmatch "Unix" )
  {
    $null = Get-ChildItem -Path $PSScriptRoot\* -Recurse | Unblock-File
  }
  $null = New-Item -ItemType Directory -Path $InstallPath -Force -ErrorAction Stop
  $null = Copy-Item $PSScriptRoot\* $InstallPath -Force -Recurse -ErrorAction Stop
  $null = Test-Path -Path $InstallPath -ErrorAction Stop
  Import-Module AGMPowerLib -Force
  $commandcheck = get-command -module AGMPowerLib
  if (!($commandcheck))
  {
    Write-Host 'Silent Installation failed.'
  }
  else {
    Write-Host 'Installed AGMPowerLib version: ' $ActModuleData.ModuleVersion 'in ' $InstallPath
  }
  exit
}

function silentinstall
{
  Write-host 'Detected PowerShell version:   ' $hostVersionInfo
  Write-host 'Downloaded AGMPowerLib version:' $ActModuleData.ModuleVersion
  $platform=$PSVersionTable.platform
  # if we find an install then we upgrade it
  [Array]$ActInstall = GetAGMPowerLibInstall
  if ($ActInstall.name.count -gt 1)
  {
    Write-Host -Object "`nMultiple installations detected.  Silent Installation failed."
  }
  # if it is installed, uninstall it, but keep the install path to re-use, otherwise use the second module path by default
  if ($ActInstall.name.count -eq 1)
  {
    $InstallPath = $ActInstall.ModuleBase
    Write-host 'Found AGMPowerLib version:     ' $ActInstall.Version 'in ' $InstallPath 
    Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop -Confirm:$false
  }
  else 
  {
    $InstallPathList = GetPSModulePath
    $InstallPath = $InstallPathList[1]
    if ( $platform -notmatch "Unix" )
    {
      $InstallPath = $InstallPath + '\AGMPowerLib\'
    }
    else 
    {
      $InstallPath = $InstallPath + '/AGMPowerLib/'
    }
  }  
  if ( $platform -notmatch "Unix" )
  {
    $null = Get-ChildItem -Path $PSScriptRoot\* -Recurse | Unblock-File
  }
  $null = New-Item -ItemType Directory -Path $InstallPath -Force -ErrorAction Stop
  $null = Copy-Item $PSScriptRoot\* $InstallPath -Force -Recurse -ErrorAction Stop
  $null = Test-Path -Path $InstallPath -ErrorAction Stop
  Import-Module AGMPowerLib -Force
  $commandcheck = get-command -module AGMPowerLib
  if (!($commandcheck))
  {
    Write-Host 'Silent Installation failed.'
  }
  else {
    Write-Host 'Installed AGMPowerLib version: ' $ActModuleData.ModuleVersion 'in ' $InstallPath
  }
  exit
}

if (($args[0] -eq "-silentinstall0") -or ($args[0] -eq "-s0"))
{
  silentinstall0
}

if (($args[0] -eq "-silentinstall") -or ($args[0] -eq "-s") -or ($args[0] -eq "-s1"))
{
    silentinstall 
}

if (($args[0] -eq "-silentuninstall")  -or ($args[0] -eq "-u"))
{
  [Array]$ActInstall = GetAGMPowerLibInstall
  foreach ($Location in ([Array]$ActInstall = GetAGMPowerLibInstall).ModuleBase)
        {
        $InstallPath = $Location
        Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop -Confirm:$false   
        }
      exit
}
Clear-Host
Write-host 'Detected PowerShell version:   ' $hostVersionInfo
Write-host 'Downloaded AGMPowerLib version:' $ActModuleData.ModuleVersion
Write-host ""

[Array]$ActInstall = GetAGMPowerLibInstall
if ($ActInstall.Length -gt 0)
{
    Write-Host 'Found an existing AGMPowerLib Module installation in the following locations:' 
    ReportAGMPowerLib | Format-Table
    write-host ""
    Write-host "Upgrade or delete menu (choose a folder to upgrade to"$ActModuleData.ModuleVersion"or choose the delete option):"
    $ActInstall += @{
        Name       = 'Delete All'
        Version    = 0.0.0.0
        ModuleBase = 'DELETE all listed installations of the AGMPowerLib Module'
        }
    $InstallPath = InstallMenu -InstallPathList $ActInstall.ModuleBase -InstallAction 'upgrade or delete'
    
    if ($InstallPath.Split(' ')[0] -eq 'DELETE')
    {
        foreach ($Location in ([Array]$ActInstall = GetAGMPowerLibInstall).ModuleBase)
        {
        $InstallPath = $Location
        RemoveModuleContent      
        }
        break
    }
    else
    {
        RemoveModuleContent
        CreateModuleContent
    }
}
else
{
    Write-Host "Could not find an existing AGMPowerLib Module installation."
    Write-Host "Where would you like to install AGMPowerLib version"$ActModuleData.ModuleVersion
    Write-Host ""
    $InstallPath = InstallMenu -InstallPathList (GetPSModulePath) -InstallAction installation
    $InstallPath = $InstallPath + '\AGMPowerLib\'
    CreateModuleContent
}

Write-Host -Object "`nAGMPowerLib Module installation location(s):"
ReportAGMPowerLib | Format-Table