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


Function Get-AGMLibBackupSKUUsage ([string]$applianceid) 
{
    <#
    .SYNOPSIS
    Displays the Backup SKU Usage for either all appliances or a nominated appliance

    .EXAMPLE
    Get-AGMLibBackupSKUUsage
    Get current Backup SKU usage for all appliances

    .EXAMPLE
    Get-AGMLibBackupSKUUsage -applianceid 1234
    Get Backup SKU Usage for the nominated appliance. 

    .DESCRIPTION
    A function to display current SKU usage.  This will not show the full month usage, just the usage in the current hour

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    $sessiontest = Get-AGMVersion
    if ($sessiontest.errormessage)
    {
        Get-AGMErrorMessage -messagetoprint "AGM session has expired. Please login again using Connect-AGM"
        return
    }
    if ($applianceid)
    {
        $appliancegrab = get-agmappliance -id $applianceid
    }
    else {
        $appliancegrab = get-agmappliance
    }
    if (!($appliancegrab))
    {
        if ($applianceid)
        {
            Get-AGMErrorMessage -messagetoprint "Could not find an appliance with ID $applianceid using Get-AGMAppliance"
        }
        else 
        {
            Get-AGMErrorMessage -messagetoprint "Could not find any appliances using Get-AGMAppliance"
        }
    }

    foreach ($appliance in $appliancegrab)
    {
        $output = Get-AGMAPIApplianceReport -applianceid $appliance.id -command reportapps
        if ($output.ApplianceName)
        {
            $AGMArray = @()

            Foreach ($id in $output)
            { 
                $skuname = "No matching SKU found"
                if ($id.AppType -eq "CIFS") { $skuname = "Default Backup SKU for VM (GCE and VMware) and File system data" }
                if ($id.AppType -eq "FileSystem") { $skuname = "Default Backup SKU for VM (GCE and VMware) and File system data" }
                if ($id.AppType -eq "GCP Instance") { $skuname = "Default Backup SKU for VM (GCE and VMware) and File system data"; $id.AppType = "GCE Instance" }
                if ($id.AppType -eq "NFS") { $skuname = "Default Backup SKU for VM (GCE and VMware) and File system data" }
                if ($id.AppType -eq "VMBackup") { $skuname = "Default Backup SKU for VM (GCE and VMware) and File system data" }
                if ($id.AppType -eq "DB2") { $skuname = "Backup SKU for DB2, Oracle, SAP HANA, SAP ASE and SAP MAXdb" }
                if ($id.AppType -eq "DB2 Instance") { $skuname = "Backup SKU for DB2, Oracle, SAP HANA, SAP ASE and SAP MAXdb" }
                if ($id.AppType -eq "MAXDB") { $skuname = "Backup SKU for DB2, Oracle, SAP HANA, SAP ASE and SAP MAXdb" }
                if ($id.AppType -eq "Oracle") { $skuname = "Backup SKU for DB2, Oracle, SAP HANA, SAP ASE and SAP MAXdb" }
                if ($id.AppType -eq "SAP ASE") { $skuname = "Backup SKU for DB2, Oracle, SAP HANA, SAP ASE and SAP MAXdb" }
                if ($id.AppType -eq "SAP HANA") { $skuname = "Backup SKU for DB2, Oracle, SAP HANA, SAP ASE and SAP MAXdb" }
                if ($id.AppType -eq "SYBASE IQ") { $skuname = "Backup SKU for DB2, Oracle, SAP HANA, SAP ASE and SAP MAXdb" }
                if ($id.AppType -eq "SYBASE Instance") { $skuname = "Backup SKU for DB2, Oracle, SAP HANA, SAP ASE and SAP MAXdb" }              
                if ($id.AppType -eq "LVM Volume") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" }    
                if ($id.AppType -eq "MARIADB") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" } 
                if ($id.AppType -eq "MARIADBInstance") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" } 
                if ($id.AppType -eq "MYSQL") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" } 
                if ($id.AppType -eq "MYSQLInstance") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" } 
                if ($id.AppType -eq "POSTGRESQL") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" } 
                if ($id.AppType -eq "POSTGRESQLInstance") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" } 
                if ($id.AppType -eq "SqlInstance") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" } 
                if ($id.AppType -eq "SQLServerAvailabilityGroup") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" } 
                if ($id.AppType -eq "SqlServerWriter") { $skuname = "Tier2 Database backup usage. Includes backup of Microsoft SQL Server, MySQL, PostgreSQL, MongoDB" } 
            $AGMArray += [pscustomobject]@{
                    appliancename = $appliance.name
                    applianceid = $appliance.id
                    apptype = $id.AppType
                    hostname = $id.HostName
                    appname = $id.AppName
                    skudescription = $skuname
                    skuusageGiB = $id."MDLStat(GB)"
                }
            }
            $AGMArray | Sort-Object -Property hostname,appname
        }
        else
        {
            $output
        }
    }
}
