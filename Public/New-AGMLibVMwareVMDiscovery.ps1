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

Function Invoke-vCenterLogin([string]$vcenter_hostname, [string]$user, [string]$passwd) {
    $password = $passwd | ConvertTo-SecureString -AsPlainText -Force
    # Create vSphere Server Configuration with the provided Credentials.
    $serverConfiguration = New-vSphereServerConfiguration -Server $vcenter_hostname -User $user -Password $password
    # Creates a Session with the vSphere API.
    $apiSession = Invoke-CreateSession -WithHttpInfo
    # Set the API Key in the vSphere Server Configuration, received with the API Session.
    $serverConfiguration = $serverConfiguration | Set-vSphereServerConfigurationApiKey -SessionResponse $apiSession
}

Function Find-vCenterEndpoint([string]$vcenter_id) {
    $vcenters = Get-AGMHost -filtervalue "isvcenterhost=true" | Select-Object id,hostname
    $vcenters | ForEach-Object {
        if ($_.id -eq $vcenter_id) {
            return $_.hostname
            break;
        }
    }
}

Function Find-TaggedVMs([string]$vmtag) {
    $vms_to_protect = @()
    Invoke-ListTag | ForEach-Object {
        $tag = Invoke-GetTagId -TagId $_
        if ($tag.name -eq $vmtag) {
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

Function New-AGMVMDiscovery([string]$vcenter_id) {
    Get-AGMAPIData -endpoint "/host/$vcenter_id/discovervm"
}

Function Get-AGMClusterName([string]$vcenter_id) {
    (Get-AGMAPIData -endpoint "host/$vcenter_id/host").name
}

# Get-Appliance, need the following fields:
# id               : 6019
# clusterid        : 142106226624

# vms should contains an array of VM uuid
Function New-AGMVMApp([string]$vcenter_host_id,[string]$cluster,[string]$clustername,[string[]]$vm_uuids)  {
    $body = [ordered]@{
        cluster=$cluster;
        addvms=$true;
        vms=$vm_uuids;
    }
    $json = $body | ConvertTo-Json

    Write-Output "New-AGMVMApp"
    Write-Output "/host/$vcenter_host_id/host/$clustername/addvms" 
    Write-Output $json
    Post-AGMAPIData -endpoint "/host/$vcenter_host_id/host/$clustername/addvms" -body $json
}

Function New-AGMLibVMwareVMDiscovery (
    [string]$discoveryfile,
    [switch]$nobackup,[switch]$backup,
    [string]$vmtag,
    [string]$sltid,[string]$sltname,[string]$slpid,[string]$slpname,
    [string]$applianceid,
    [string]$vcenterid,
    [decimal]$limit,
    [string]$vcenter_user,[string]$vcenter_passwd,
    [switch]$noparallel,
    [switch]$verbose,
    [switch]$textoutput
)
{

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    # verbose = textoutput
    if ($verbose) { $textoutput = $true}
    if ($textoutput)
    {
        $ct = Get-Date
        write-host "$ct Starting function"
    }

    $sessiontest = Get-AGMVersion
    if ($sessiontest.errormessage)
    {
        $sessiontest
        return
    }
    if ($textoutput)
    {
        $ct = Get-Date
        write-host "$ct Session test passed"
    }

    $vcenter_hostname = Find-vCenterEndpoint -vcenter_id $vcenterid
    if (!$vcenter_hostname) {
        Get-AGMErrorMessage -messagetoprint "Cannot find the vCenter with specified vcenter_id $vcenterid!"
        return
    }

    Invoke-vCenterLogin -vcenter_hostname $vcenter_hostname -user $vcenter_user -passwd $vcenter_passwd
    
    $appliance = Get-AGMAppliance -filtervalue "clusterid=$applianceid"

    $vms_to_protect = Find-TaggedVMs -vmtag $vmtag

    $vms_to_protect_discovered = @()
    $vms_already_protected = @()
    $vms_cant_be_discovered = @()
    $discovered_vms = New-AGMVMDiscovery -vcenter_id $vcenterid
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

    $clustername = Get-AGMClusterName -vcenter_id $vcenterid 
    New-AGMVMApp -vcenter_host_id $vcenterid -cluster $appliance.id -clustername $clustername -vm_uuids $vms_to_protect_discovered.uuid

    # Waiting for all apps being added
    # Check it every 10 seconds until all apps are added
    $filter_apps = $vms_to_protect_discovered | Join-String -Property vmname -Separator "&" -FormatString "appname={0}"
    while ($true) {
        $all_apps = (Get-AGMApplication -filtervalue $filter_apps).where{$_.isorphan -match $false}
        if ($all_apps.count -eq $vms_to_protect_discovered.count) {
            break
        }

        Start-Sleep -Seconds 10
    }

    Write-Output "Successfully added new applications for tagged VMs"

    # if ($nobackup) {
    #     return
    # }

    $new_sla_list = @()
    $all_apps = (Get-AGMApplication -filtervalue $filter_apps).where{$_.isorphan -match $false}
    $all_apps | ForEach-Object {
        $new_sla_list += [pscustomobject]@{
            appid = $_.id
            sltid = $sltid
            slpid = $slpid
        }
    }

    Write-Output "SLA List:"
    Write-Output $new_sla_list

    $new_sla_list | ForEach-Object {
        $new_sla_cmd = 'New-AGMSLA -appid ' +$_.appid +' -sltid ' +$_.sltid +' -slpid ' +$_.slpid
        if ($textoutput) {
            $ct = Get-Date
            write-host "$ct Running" $new_sla_cmd
        }

        Invoke-Expression $new_sla_cmd
    }

    Write-Output "Successfully protected tagged VMs"

}
