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

function Find-TaggedVMs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $VmTag
    )

    $vms_to_protect = @()
    Invoke-ListTag | ForEach-Object {
        $tag = Invoke-GetTagId -TagId $_
        if ($tag.name -eq $VmTag) {
            $tagged_vms = Invoke-ListAttachedObjectsTagIdTagAssociation -TagId $tag.id | Where-Object {$_.type -eq "VirtualMachine"}
            
            $tagged_vms | ForEach-Object {
                $vm_details = Invoke-GetVm -Vm $_.id
                $vms_to_protect += [pscustomobject]@{
                    id = $_.id
                    name = $vm_details.name
                    uuid = $vm_details.identity.instance_uuid
                }
            }
            break
        }
    }

    return $vms_to_protect
}

<#
.SYNOPSIS

#>
function New-AGMLibVMwareVMDiscovery {
    [CmdletBinding()]
    param (
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
        [int]
        $applianceid,
        
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

        # The id of the vCenter host.
        [Parameter(Mandatory = $true)]
        [int]
        $vcenterid,

        # The maximum number of VMs will be affected at the same time.
        # Deafult value is 5
        [Parameter(Mandatory = $false)]
        [int]
        $parallelism = 5
    )

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) ) {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }

    Write-Verbose "$(Get-Date) Starting New-AGMLibVMwareVMDiscovery function"

    if ($backup) {
        $nobackup.IsPresent = $false
    } else {
        $nobackup.IsPresent = $true
    }

    $session_test = Get-AGMVersion
    if ($session_test.errormessage) {
        $session_test
        return
    }

    Write-Verbose "$(Get-Date) Session test passed"

    $vcenter_hostname = Find-vCenterHostname -vCenterId $vcenterid
    if (!$vcenter_hostname) {
        Get-AGMErrorMessage -messagetoprint "Cannot find the vCenter with specified vcenter_id $vcenterid!"
        return
    }
    
    $appliance = Get-AGMAppliance -filtervalue "clusterid=$applianceid"

    $vms_to_protect = Find-TaggedVMs -VmTag $vmtag

    $vms_to_protect_discovered = @()
    $vms_already_protected = @()
    $vms_cant_be_discovered = @()
    $discovered_vms = New-AGMVMDiscovery -vCenterId $vcenterid
    $discovered_vms | ForEach-Object {
        # Make sure the discovered VMs contains the VM we want to protect.
        # Skip those VMs that have been already protected
        if ($vms_to_protect.name.Contains($_.vmname)) {
            if ($_.exists -eq $true) {
                $vms_already_protected += $_
            } else {
                $vms_to_protect_discovered += $_
            }
        } else {
            $vms_cant_be_discovered += $_
        }
    }

    Write-Output "Protecting VMs: "
    Write-Output $vms_to_protect_discovered.vmname

    $clustername = Get-AGMClusterName -vCenterId $vcenterid 
    New-AGMVMApp -vCenterId $vcenterid -Cluster $appliance.id -ClusterName $clustername -VmUUIDs $vms_to_protect_discovered.uuid

    # Waiting for all apps being added
    # Check it every 10 seconds until all apps are added
    $filter_apps = $vms_to_protect_discovered | Join-String -Property vmname -Separator "&" -FormatString "appname={0}"
    while ($true) {
        Write-Verbose "Waiting for all applications being created..."

        $all_apps = (Get-AGMApplication -filtervalue $filter_apps).where{$_.isorphan -match $false}
        if ($all_apps.count -eq $vms_to_protect_discovered.count) {
            Write-Verbose "All applications have been created successfully."
            break
        }

        Start-Sleep -Seconds 10
    }

    Write-Output "Successfully added new applications for tagged VMs"

    if ($nobackup) {
        Write-Output "-nobackup option enabled, won't apply SLA to apps, exit."
        return
    }

    Write-Output "Applying SLA to new applications"

    $new_sla_list = @()
    $all_apps = (Get-AGMApplication -filtervalue $filter_apps).where{$_.isorphan -match $false}
    $all_apps | ForEach-Object -ThrottleLimit $parallelism -Parallel {
        $new_sla_list += [pscustomobject]@{
            appid = $_.id
            sltid = $sltid
            slpid = $slpid
        }
    }

    Write-Output "SLA List:"
    Write-Output $new_sla_list

    $new_sla_list | ForEach-Object -ThrottleLimit $parallelism -Parallel {
        $new_sla_cmd = 'New-AGMSLA -appid ' +$_.appid +' -sltid ' +$_.sltid +' -slpid ' +$_.slpid
        
        Write-Verbose "$(Get-Date) Running $new_sla_cmd"

        Invoke-Expression $new_sla_cmd
    }

    Write-Output "Successfully protected tagged VMs"

}
