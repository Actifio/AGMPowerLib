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
#
# Module manifest for module 'AGMPowerLib'
#
# Generated by: Anthony Vandewerdt
#
# Generated on: 10/7/2020
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'AGMPowerLib.psm1'

# Version number of this module.
ModuleVersion = '0.0.0.72'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '6155fdbc-7393-48a8-a7ac-9f5f69f8887b'

# Author of this module
Author = 'Anthony Vandewerdt'

# Company or vendor of this module
CompanyName = 'Google'

# Copyright statement for this module
Copyright = '(c) 2022 Google, Inc. All rights reserved'

################################################################################################################## 
# Description of the functionality provided by this module
Description = 'This is a community generated PowerShell Module for Actifio Global Manager (AGM).  
It provides composite functions that combine commands to various AGM API endpoints, to achieve specific outcomes. 
Examples include mounting a database, creating a new VM or running a workflow.
More information about this module can be found here:   https://github.com/Actifio/AGMPowerLib'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.0'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('AGMPowerCLI')

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Confirm-AGMLibComputeEngineImage',
'Confirm-AGMLibComputeEngineProject',
'Export-AGMLibSLT',
'Get-AGMLibActiveImage',
'Get-AGMLibApplicationID',
'Get-AGMLibApplianceLogs',
'Get-AGMLibApplianceParameter',
'Get-AGMLibAppPolicies',
'Get-AGMLibBackupSKUUsage',
'Get-AGMLibContainerYAML',
'Get-AGMLibCredentialSrcID',
'Get-AGMLibHostID',
'Get-AGMLibHostList',
'Get-AGMLibImageDetails',
'Get-AGMLibImageRange',
'Get-AGMLibFollowJobStatus',
'Get-AGMLibLastPostCommand',
'Get-AGMLibLatestImage',
'Get-AGMLibPolicies',
'Get-AGMLibRunningJobs',
'Get-AGMLibSLA',
'Get-AGMLibWorkflowStatus',
'Import-AGMLibOnVault',
'Import-AGMLibPDSnapshot',
'Import-AGMLibSLT',
'New-AGMLibAWSVM',
'New-AGMLibAzureVM',
'New-AGMLibContainerMount',
'New-AGMLibGCPInstance',
'New-AGMLibDb2Mount',
'New-AGMLibFSMount',
'New-AGMLibGCEConversion',
'New-AGMLibGCEConversionMulti',
'New-AGMLibGCEInstanceDiscovery',
'New-AGMLibGCEMountExisting',
'New-AGMLibGCVEfailover',
'New-AGMLibGCPInstance',
'New-AGMLibGCPInstanceMultiMount',
'New-AGMLibGCPVM',
'New-AGMLibImage',
'New-AGMLibLVMMount',
'New-AGMLibMultiMount',
'New-AGMLibMSSQLClone',
'New-AGMLibMSSQLMount',
'New-AGMLibMSSQLMulti',
'New-AGMLibMySQLMount',
'New-AGMLibPostgreSQLMount',
'New-AGMLibSAPHANAMount',
'New-AGMLibSAPHANAMultiMount',
'New-AGMLibVM',
'New-AGMLibVMMultiMount',
'New-AGMLibMultiVM',
'New-AGMLibOracleMount',
'New-AGMLibMSSQLMigrate',
'New-AGMLibSystemStateToVM',
'New-AGMLibVMExisting',
'Remove-AGMLibMount',
'Restore-AGMLibMount',
'Restore-AGMLibSAPHANA',
'Set-AGMLibApplianceParameter',
'Set-AGMLibImage',
'Set-AGMLibMSSQLMigrate',
'Set-AGMLibSLA',
'Start-AGMLibWorkflow',
'Start-AGMLibPolicy',
'Start-AGMLibRansomwareRecovery')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @("Actifio","AGM","Sky","CDS","CDX","VDP","ActifioGO")

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/Actifio/AGMPowerLib/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/Actifio/AGMPowerLib'

        # A URL to an icon representing this module.
        IconUri = 'https://i.imgur.com/QAaK5Po.jpg'

        # ReleaseNotes of this module
        ReleaseNotes = ''

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

