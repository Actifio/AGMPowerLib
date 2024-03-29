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

<#
.SYNOPSIS
Uses specified vCenter ID, appliance ID or a pre-prepared CSV list of vCenter IDs, appliance IDs, to discover new VMWare VMs.

.DESCRIPTION
This routine needs a well formatted CSV file that contains applianceid and vcenterid
Note the column order is not important.    
Here is an example of such a file:

applianceid,vcenterid
143112195179,2110151
143112195179,2110122
143112195179,2110114

To learn applianceid (clusterid), use Get-AGMAppliance

The default is to fetch 5 Instances at a time.  You can change this with -limit.
You can also manually supply applianceid and vcenterid rather than using a CSV file

If sltid/sltname and sltname/slpname are not specified, it will default to -nobackup option.
-nobackup option is mutually exclusive with sltid/sltname or sltname/slpname
If -nobackup is specified then discovery will occur with no backup plans being applied.

If the following are specified in combination then all instances will have a backup plan applied to it:
-backup -sltname "<name1>" -slpname "<name2>"
-backup -sltid <slt ID learned with Get-AGMSLT> -slpid <slp ID learned with Get-AGMSLP>

.EXAMPLE
New-AGMLibVMwareVMDiscovery -vmtag mytag -discoveryfile discovery.csv -username user-01@abc.com

.EXAMPLE
New-AGMLibVMwareVMDiscovery -vmtag mytag -discoveryfile discovery.csv -nobackup -username user-01@abc.com

.EXAMPLE
New-AGMLibVMwareVMDiscovery -vmtag mytag -discoveryfile discovery.csv -sltid 2121511 -slpid 6006 -username user-01@abc.com -passfilepath '.vcenterpass'

.EXAMPLE
New-AGMLibVMwareVMDiscovery -vmtag mytag -discoveryfile discovery.csv -sltname LocalSnap -slpname LocalProfile -username user-01@abc.com -passfilepath '.vcenterpass'

.EXAMPLE
New-AGMLibVMwareVMDiscovery -vmtag mytag -applianceid 143112195179 -vcenterid 2110151 -username user-01@abc.com -passfilepath '.vcenterpass'

.EXAMPLE
New-AGMLibVMwareVMDiscovery -vmtag mytag -applianceid 143112195179 -vcenterid 2110151 -nobackup -username user-01@abc.com -passfilepath '.vcenterpass'

.EXAMPLE
New-AGMLibVMwareVMDiscovery -vmtag mytag -applianceid 143112195179 -vcenterid 2110151 -sltid 2121511 -slpid 6006 -username user-01@abc.com -passfilepath '.vcenterpass'

.EXAMPLE
New-AGMLibVMwareVMDiscovery -vmtag mytag -applianceid 143112195179 -vcenterid 2110151 -sltname LocalSnap -slpname LocalProfile -username user-01@abc.com -passfilepath '.vcenterpass'
#>
function New-AGMLibVMwareVMDiscovery {
    [CmdletBinding()]
    param (
        # The user name for logging into the vCenter
        [Parameter(Mandatory = $true)]
        [string]
        $username,

        # File that saves the encrypted password
        [Parameter(Mandatory = $false)]
        [string]
        $passfilepath,

        # The file path for the discovery file.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDiscoveryFileNoBackup')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDiscoveryFileBackupUseId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDiscoveryFileBackupUseName')]
        [string]
        $discoveryfile,

        # The applianceid attribute of an appliance.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceNoBackup')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseName')]
        [string]
        $applianceid,

        # The id of the vCenter host.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceNoBackup')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseName')]
        [string]
        $vcenterid,
        
        # Mutually exclusive with -backup option, this option is enabled by default.
        # Enable this option will not apply SLAs to the new applications.
        [Parameter(Mandatory = $false, ParameterSetName = 'UseDiscoveryFileNoBackup')]
        [Parameter(Mandatory = $false, ParameterSetName = 'UseSpecifiedApplianceNoBackup')]
        [switch]
        $nobackup,

        # Mutually exclusive with -nobackup option, this option has to be enabled explicitly.
        # Enable this option will apply SLAs to the new applications.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDiscoveryFileBackupUseId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDiscoveryFileBackupUseName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseName')]
        [switch]
        $backup,

        # The VM tag that want to discover in the vCenter.
        [Parameter(Mandatory = $true)]
        [string]
        $vmtag,

        # The id of the SLT
        # Mutually exclusive with -sltname and -slpname options.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDiscoveryFileBackupUseId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseId')]
        [int]
        $sltid,

        # The id of the SLP
        # Mutually exclusive with -sltname and -slpname options.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDiscoveryFileBackupUseId')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseId')]
        [int]
        $slpid,

        # The name of the SLT
        # Mutually exclusive with -sltid and -slpid options.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDiscoveryFileBackupUseName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseName')]
        [string]
        $sltname,

        # The name of the SLP
        # Mutually exclusive with -sltid and -slpid options.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseDiscoveryFileBackupUseName')]
        [Parameter(Mandatory = $true, ParameterSetName = 'UseSpecifiedApplianceBackupUseName')]
        [string]
        $slpname,

        # The maximum number of VMs will be affected at the same time.
        # Default value is 5
        [Parameter(Mandatory = $false)]
        [int]
        $parallelism = 5,

        # Timeout (seconds) for waiting applications being created.
        # Default value is 600 (seconds)
        # You may need to increase this value when you have numerous VMs with the tag.
        [Parameter(Mandatory = $false)]
        [int64]
        $timeout = 600
    )

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) ) {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }

    Write-Verbose "$(Get-Date) Starting New-AGMLibVMwareVMDiscovery function`n"

    $nobackup = $backup ? $false : $true

    $session_test = Get-AGMVersion
    if ($session_test.errormessage) {
        $session_test
        return
    }

    Write-Verbose "$(Get-Date) Session test passed`n"

    if ($discoveryfile) {
        if ( Test-Path -Path $discoveryfile ) {
            Write-Output "Reading applianceid and vcenterid list from the discovery file.`n"
            $search_list = Import-Csv -Path $discoveryfile
        }
        else {
            Get-AGMErrorMessage -messagetoprint "The specified discovery file does not exist.`n"
            return
        }
    }
    else {
        Write-Output "Using the user supplied applianceid and vcenterid.`n"
        $search_list = @(
            [PSCustomObject]@{
                applianceid = $applianceid
                vcenterid   = $vcenterid
            }
        )
    }

    if ($sltid -and $slpid) {
        Invoke-ValidatePrameters -SltId $sltid -SlpId $slpid -ErrorAction Stop
    }
    elseif ($sltname -and $slpname) {
        Invoke-ValidatePrameters -SltName $sltname -SlpName $slpname -ErrorAction Stop
    }

    # Loop over the applianceid and vcenterid list, apply SLA to all the tagged VMs.
    $search_list | ForEach-Object {
        $appliance_id = $_.applianceid
        $vcenter_id = $_.vcenterid

        Write-Output "Discovering VMs with applianceid=$appliance_id, vcenterid=$vcenter_id ..."

        $vcenter_hostname = Find-vCenterHostname -vCenterId $vcenter_id
        if (!$vcenter_hostname) {
            Get-AGMErrorMessage -messagetoprint "Cannot find the vCenter with specified vcenter_id $vcenter_id!"
            return
        }

        Connect-vCenter -vCenterHostName $vcenter_hostname -UserName $username -PassFilePath $passfilepath 
        
        $appliance = Get-AGMAppliance -filtervalue "clusterid=$appliance_id"

        $vcenter_vms_to_protect = Find-vCenterTaggedVMs -VmTag $vmtag
        $vms_to_protect = @()
        New-AGMVMDiscovery -vCenterId $vcenter_id | ForEach-Object {
            # Make sure the discovered VMs contains the VM we want to protect.
            # Skip those VMs that have been already protected
            if (!$vcenter_vms_to_protect.uuid.Contains($_.uuid)) {
                return
            }

            $vms_to_protect += $_
        }

        Write-Output "Discovering VMs - Done`n"

        # Group VMs by clustername
        $vms_grouped_by_clustername = $vms_to_protect | Group-Object -Property "clustername"
        
        Write-Output "Clusters need to be processed: $($vms_grouped_by_clustername.Name)"
        
        # Loop over groupped VMs to create app and apply SLA
        $vms_grouped_by_clustername | ForEach-Object {
            $cluster_name = $_.Name
            $vms_group = $_.Group

            Write-Output "Now processing the cluster: $cluster_name"

            $vms_to_create_app = @()
            $vms_already_created_app = @()
            $vms_group | ForEach-Object {
                if ($_.exists -eq $true) {
                    $vms_already_created_app += $_
                }
                else {
                    $vms_to_create_app += $_
                }
            }

            if ($vms_already_created_app.count -gt 0) {
                Write-Output "VMs have already created an application: $($vms_already_created_app.vmname)`n"
            }
    
            if ($vms_to_create_app.count -gt 0) {
                Write-Output "Creating applications for the VMs: $($vms_to_create_app.vmname)`n"
    
                New-AGMVMApp -vCenterId $vcenter_id -Cluster $appliance.id -ClusterName $cluster_name -VmUUIDs $vms_to_create_app.uuid
    
                Invoke-WaitingAppsCreationCompleted -VmsToCreateApp $vms_to_create_app
            }
            else {
                Write-Output "Do not need to create applications for the tagged VMs.`n"
            }

            if ($nobackup) {
                Write-Output "-nobackup option enabled, won't apply SLA to applications.`n"
                return
            }
            
            $apps_filter = $vms_to_protect | Join-String -Property uuid -OutputPrefix "apptype=VMBackup&" -Separator "&" -FormatString "uniquename={0}"
            $all_apps = Get-AGMApplication -filtervalue $apps_filter
    
            $apps_protectable = $all_apps | Where-Object { ($_.isprotected -eq $false) -and ($_.protectable -eq 1) }
            $apps_already_protected = $all_apps | Where-Object { $_.isprotected -eq $true }
    
            if ($apps_already_protected.count -gt 0) {
                Write-Output "$($apps_already_protected.count) applications have already been protected: $($apps_already_protected.appname)`n"
            }
    
            if ($apps_protectable.count -le 0) {
                Write-Warning "No protectable applications.`n"
                return
            }

            Write-Output "Protecting applications: $($apps_protectable.appname)`n"
    
            Write-Output "Fetching SLA list...`n"
    
            $new_sla_list = @()
            $apps_protectable | ForEach-Object {
                $new_sla_list += [PSCustomObject]@{
                    appid = $_.id
                    sltid = $sltid
                    slpid = $slpid
                }
            }
    
            Write-Output "SLA list:"
            Write-Output $new_sla_list
    
            Write-Output "`nApplying SLA to all protectable applications...`n"
            $new_sla_list | ForEach-Object -ThrottleLimit $parallelism -Parallel {
                $VerbosePreference = $using:VerbosePreference
                $agmip = $using:agmip
                $AGMSESSIONID = $using:AGMSESSIONID
                $AGMToken = $using:AGMToken
    
                $new_sla_cmd = 'New-AGMSLA -appid ' + $_.appid + ' -sltid ' + $_.sltid + ' -slpid ' + $_.slpid
                Write-Verbose "$(Get-Date) Running $new_sla_cmd`n"
    
                New-AGMSLA -appid $_.appid -sltid $_.sltid -slpid $_.slpid > $null
                Start-Sleep -Seconds 5
            }
    
            Write-Output "Successfully protected tagged VMs for Cluster: $cluster_name, vCenter ID: $vcenter_id, Appliance applianceid: $appliance_id, Appliance Name: $($appliance.name)!`n"
        }
    }

    Write-Output "Successfully protected all tagged VMs!`n"
}

function Invoke-WaitingAppsCreationCompleted {
    [CmdletBinding()]
    param (
        # VMs that need to create an application for.
        [Parameter(Mandatory)]
        [PSCustomObject[]]
        $VmsToCreateApp
    )

    # Waiting for all apps being added
    # Check it every 10 seconds until all apps are added
    $start_ts = [int64](Get-Date -UFormat %s)
    $apps_filter = $VmsToCreateApp | Join-String -Property uuid -OutputPrefix "apptype=VMBackup&" -Separator "&" -FormatString "uniquename={0}"
    while ($true) {
        $all_apps = Get-AGMApplication -filtervalue $apps_filter

        # Show progress
        $progress = 100 * ($all_apps.count / $VmsToCreateApp.count)
        Write-Progress -Activity "Applications creation in progress" -Status $("{0:F2}% Completed" -f $progress) -PercentComplete $progress

        if ($all_apps.count -eq $VmsToCreateApp.count) {
            Write-Progress "Applications creation - Done" "Done" -Completed
            Write-Output "All applications have been created successfully.`n"
            break
        }

        if (([int64](Get-Date -UFormat %s) - $start_ts) -ge $timeout) {
            Write-Warning "Timeout ($timeout secs) while waiting for all applications being created.`n"
            Write-Warning "Applications have been created so far: $($all_apps.appname)`n"
            break
        }

        Start-Sleep -Seconds 10
    }
}

function Invoke-ValidatePrameters {
    [CmdletBinding()]
    param (
        # The id of the SLT
        # Mutually exclusive with -sltname and -slpname options.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseId')]
        [int]
        $SltId,

        # The id of the SLP
        # Mutually exclusive with -sltname and -slpname options.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseId')]
        [int]
        $SlpId,

        # The name of the SLT
        # Mutually exclusive with -sltid and -slpid options.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseName')]
        [string]
        $SltName,

        # The name of the SLP
        # Mutually exclusive with -sltid and -slpid options.
        [Parameter(Mandatory = $true, ParameterSetName = 'UseName')]
        [string]
        $SlpName
    )

    # Get SLT and SLP ids if sltname and slpname are passed in
    $slt_filter = "id=$SltId"
    $slp_filter = "id=$SlpId"
    if ($SltName -and $SlpName) {
        $slt_filter = "name=$SltName"
        $slp_filter = "name=$SlpName"
    }

    $slt = Get-AGMSLT -filtervalue $slt_filter
    $slp = Get-AGMSLP -filtervalue $slp_filter

    if (!$slt.id -or !$slp.id) {
        throw "The specified slt id/name or the slp id/name does not exist."
    }

}