# AGMPowerLib

A Powershell module that allows PowerShell users to issue complex API calls to Actifio Global Manager. This module contains what we call composite functions, these being complex combination of API endpoints.  

### Table of Contents
**[Prerequisites](#prerequisites)**<br>
**[Install or upgrade AGMPowerLib](#install-or-upgrade-agmpowerlib)**<br>
**[Guided Wizards](#guided-wizards)**<br>
**[Usage Examples](#usage-examples)**<br>
**[User Stories](#user-stories)**<br>
**[Contributing](#contributing)**<br>
**[Disclaimer](#disclaimer)**<br>

## Prerequisites

This module requires AGMPowerCLI to already be installed.
Please visit this repo first:  https://github.com/Actifio/AGMPowerCLI
Once you have installed AGMPowerCLI, then come back here and install AGMPowerLib to get the composite functions.


## Install or upgrade AGMPowerLib

There are two ways to install AGMPowerCLI:

* PowerShell Gallery
* Github

### Install using PowerShell Gallery

Install from PowerShell Gallery is the simplest approach.

If running PowerShell 5 on Windows first run this (some older Windows versions are set to use downlevel TLS which will result in confusing error messages):
```
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```
Now run this command. It is normal to get prompted to upgrade or install the NuGet Provider.  You may see other warnings as well.

```
Install-Module -Name AGMPowerLib
```

### Upgrades using PowerShell Gallery

Note if you run 'Install-Module' to update an installed module, it will complain.  You need to run 'Update-module' instead.

If running PowerShell 5 on Windows first run this (some older Windows versions are set to use downlevel TLS which will result in confusing error messages):
```
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```
Now run this command:
```
Update-Module -name AGMPowerLib
```
It will install the latest version and leave the older version in place.  To see the version in use versus all versions downloaded use these two commands:
```
Get-InstalledModule AGMPowerLib
Get-InstalledModule AGMPowerLib -AllVersions
```
To uninstall all older versions run this command:
```
$Latest = Get-InstalledModule AGMPowerLib; Get-InstalledModule AGMPowerLib -AllVersions | ? {$_.Version -ne $Latest.Version} | Uninstall-Module
```

Many corporate servers will not allow downloads from PowerShell gallery or even access to GitHub from Production Servers, so for these use one of the Git download methods below.

### Clone the Github repo

1.  Using a GIT client on your Windows or Linux or Mac OS host, clone the AGMPowerLIB GIT repo (see example clone command below)
1.  Now start PWSH and change directory to the AGMPowerLib directory that should contain our module files.
1.  There is an installer file: **Install-AGMPowerLib.ps1** so run that with **./Install-AGMPowerLib.ps1**  

If it finds multiple installs, we strongly recommend you delete them all and run the installer again to have just one install.

The GIT repo could be cloned with this command:
```
git clone https://github.com/Actifio/AGMPowerLIB.git AGMPowerLIB
```
##### Manual ZIP Download

1.  From GitHub, use the Green Code download button to download the AGMPowerLib repo as a zip file.  Normally you would use the **Main** branch for this unless requested otherwise.  
1.  Copy the Zip file to the server where you want to install it
1.  For Windows, Right select on the zip file, choose  Properties and then use the **Unblock** button next to the message:  *This file came from another computer and might be blocked to help protect  your computer.*
1.  For Windows, now right select and use **Extract All** to extract the contents of the zip file to a folder.  It doesn't matter where you put the folder.  For Mac it should automatically unzip.  For Linux use the unzip command to unzip the folder. 
1.  Now start PWSH and change directory to the AGMPowerLib-main directory that should contain our module files.   
1.  There is an installer file: **Install-AGMPowerLib.ps1** so run that with **./Install-AGMPowerLib.ps1**  
If it finds multiple installs, we strongly recommend you delete them all and run the installer again to have just one install.

For Download you could also use this:
```
wget https://github.com/Actifio/AGMPowerLib/archive/refs/heads/main.zip
pwsh
Expand-Archive ./main.zip
./main/AGMPowerLib-main/Install-AGMPowerLib.ps1
rm main.zip
rm -r main
```

If the install fails with this (which usually occurs if you didn't unblock the zip file):
```
PS C:\Users\av\Downloads\AGMPowerLib-main\AGMPowerLib-main> .\Install-AGMPowerLib.ps1
.\Install-AGMPowerLib.ps1: File C:\Users\av\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 cannot be loaded. 
The file C:\Users\av\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 is not digitally signed. 
You cannot run this script on the current system. For more information about running scripts and setting execution policy, see about_Execution_Policies at https://go.microsoft.com/fwlink/?LinkID=135170.
```
Then run this command:
```
Get-ChildItem .\Install-AGMPowerLib.ps1 | Unblock-File
```
Then re-run the installer.  The installer will unblock the remaining files.

#### Silent Install

You can run a silent install by adding **-silentinstall** or **-silentinstall0**

* **-silentinstall0** or **-s0** will install the module in 'slot 0'
* **-silentinstall** or **-s** will install the module in 'slot 1' or in the same location where it is currently installed
* **-silentuninstall** or **-u** will silently uninstall the module.   You may need to exit the session to remove the module from memory

By slot we mean the output of **$env:PSModulePath** where 0 is the first module in the list, 1 is the second module and so on.
If the module is already installed, then if you specify **-silentinstall** or **-s** it will reinstall in the same folder.
If the module is not installed, then by default it will be installed into path 1
```
PS C:\Windows\system32>  $env:PSModulePath.split(';')
C:\Users\avw\Documents\WindowsPowerShell\Modules <-- this is 0
C:\Program Files (x86)\WindowsPowerShell\Modules <-- this is 1
PS C:\Windows\system32>
```
Or for Unix:
```
PS /Users/avw> $env:PSModulePath.Split(':')
/Users/avw/.local/share/powershell/Modules    <-- this is 0
/usr/local/share/powershell/Modules           <-- this is 1
```
Here is an example of a silent install:
```
PS C:\Windows\system32> C:\Users\avw\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 -silentinstall 
Detected PowerShell version:    5
Downloaded AGMPowerLib version: 0.0.0.35
Installed AGMPowerLib version:  0.0.0.35 in  C:\Program Files (x86)\WindowsPowerShell\Modules\AGMPowerLib\
```
Here is an example of a silent upgrade:
```
PS C:\Windows\system32> C:\Users\avw\Downloads\AGMPowerLib-main\AGMPowerLib-main\Install-AGMPowerLib.ps1 -silentinstall 
Detected PowerShell version:    5
Downloaded AGMPowerLib version: 0.0.0.34
Found AGMPowerLib version:      0.0.0.34 in  C:\Program Files (x86)\WindowsPowerShell\Modules\AGMPowerLib
Installed AGMPowerLib version:  0.0.0.35 in  C:\Program Files (x86)\WindowsPowerShell\Modules\AGMPowerLib
PS C:\Windows\system32>
```

#### Silent Uninstall

You can uninstall the module silently by adding **-silentuninstall** or **-u**  to the Install command.  

# Usage Examples

Usage examples are in a separate document that you will find [here](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md)

## User Stories 
All User Stories were moved to [here](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md)

The following examples were all moved from the Readme to the Usage Examples page but are here in case you bookmarked them:

#### [User Story: Appliance parameter management and slot limits](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#appliance-parameter-and-slot-management)
#### [User Story: Auto adding GCE Instances and protecting them with tags](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#compute-engine-instance-onboarding-automation)
#### [User Story: Creating GCE Instance from PD Snapshots](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#compute-engine-instance-mount)
#### [User Story: Creating GCE Instance from VMware Snapshots](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#compute-engine-instance-conversion-from-vmware-vm)
#### [User Story: Displaying Backup SKU Usage](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#backup-sku-usage)
#### [User Story: Displaying Backup Plan Policies](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#backup-plan-policy-usage)
#### [User Story: File System multi-mount for Ransomware analysis](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#multi-Mount-for-ransomware-analysis)
#### [User Story: GCE Disaster Recovery using GCE Instance PD Snapshots](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#compute-engine-instance-multi-mount-disaster-recovery)
#### [User Story: GCE Disaster Recovery using VMware VM Snapshots](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#compute-engine-instance-multi-conversion-from-vmware-vm)
#### [User Story: Importing and Exporting AGM Policy Templates](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#importing-and-exporting-policy-templates)
#### [User Story: Importing OnVault images](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#image-import-from-onvault)
#### [User Story: Microsoft SQL Mount and Migrate](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#sql-server-mount-and-migrate)
#### [User Story: Microsoft SQL Multi Mount and Migrate](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#sql-server-multi-mount-and-migrate)
#### [User Story: Protecting and re-winding child apps](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#sql-server-protecting-and-rewinding-child-apps)
#### [User Story: Running on-demand jobs based on application ID](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#image-creation-with-an-ondemand-job)
#### [User Story: Running on-demand jobs based on policy ID](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#image-creation-in-bulk-using-policy-id)
#### [User Story: Running a workflow](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#running-a-workflow)
#### [User Story: SAP HANA Database Mount](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#sap-hana-mount)
#### [User Story: SQL Test and Dev Image usage](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#sql-server-database-mount)
#### [User Story: SQL DB mount of an Orphan image](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#sql-server-database-mount)
#### [User Story: SQL Test and Dev Image usage with point in time recovery](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#sql-server-mount-with-point-in-time-recovery)
#### [User Story: SQL Instance Test and Dev Image usage](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#sql-server-instance-mount)
#### [User Story: VMware multi-mount](https://github.com/Actifio/AGMPowerCLI/blob/main/UsageExamples.md#vmware-multi-mount)

## Contributing

Have a patch that will benefit this project? Awesome! Follow these steps to have
it accepted.

1.  Please sign our [Contributor License Agreement](CONTRIBUTING.md).
1.  Fork this Git repository and make your changes.
1.  Create a Pull Request.
1.  Incorporate review feedback to your changes.
1.  Accepted!

## License

All files in this repository are under the
[Apache License, Version 2.0](LICENSE) unless noted otherwise.

## Disclaimer
This is not an official Google product.
