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


Function New-AGMLibGCEInstanceDiscovery ([string]$discoveryfile,[switch]$nobackup,[switch]$backup,[string]$usertag,[string]$credentialid,[string]$applianceid,[string]$project,[string]$zone) 
{
     <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of cloud credential IDs, appliance IDs, projects and zones to discover new GCE Instances

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -sourcefile credentials.csv -nobackup

    Adds all new GCE Instances discovered in the nominated projects and zones as unmanaged applications

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -sourcefile credentials.csv -backup

    Adds all new GCE Instances discovered in the nominated projects and zones and protects any that have a label named googlebackupplan and a valid template name

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -sourcefile credentials.csv -backup -usertag "corporatepolicy"

    Adds all new GCE Instances discovered in the nominated projects and zones and protects any that have a label named corporatepolicy and a valid template name

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -credentialid 259643 -applianceid 141805487622 -projectid avwservicelab1 -zone australia-southeast1-b -usertag backupplan -backup

    Instead os using a discovery file the four required variables are specified by the user.

    .DESCRIPTION
    This routine needs a well formatted CSV file that contains cloud credential ID
    Note the column order is not important.    
    Here is an example of such a file:

    credentialid,applianceid,project,zone
    6654,143112195179,avwarglab1,australia-southeast1-c
    6654,143112195179,avwarglab1,australia-southeast2-a
    6654,143112195179,avwarglab1,australia-southeast2-b

    To learn credential ID and appliance ID, use Get-AGMLibCredentialSrcID
    Then use the desired projects (where the service account for the credential exists) and the desired zones you want to check for new Instances.

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

    if (($credentialid) -and ($applianceid) -and ($project) -and ($zone))
    {
        $searchlist = @()
        $searchlist += [pscustomobject]@{
            credentialid = $credentialid
            applianceid = $applianceid
            project = $project
            zone = $zone
        }
    }
    elseif ($discoveryfile)
    {
        $searchlist = Import-Csv -Path $discoveryfile
    }
    else
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a source csv file correctly formatted as per the help for this function using: -discoveryfile xxxx.csv"
        return;
    }

    if ($nobackup)
    {
        foreach ($cred in $searchlist)
        {
            $done = 0
            do 
            {
                $searchcommand = 'Get-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone
                $runcommand = Invoke-Expression $searchcommand
                if ($runcommand.totalcount -gt 0)
                {
                    foreach ($instance in $runcommand.items.vm)
                    {
                        $addcommand = 'New-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -instanceid ' +$instance.instanceid
                        $runcommand = Invoke-Expression $addcommand
                    }
                }
                else 
                {
                    $done = 1
                }
                $runcommand | Add-Member -NotePropertyName credentialid -NotePropertyValue $cred.credentialid
                $runcommand | Add-Member -NotePropertyName applianceid -NotePropertyValue $cred.applianceid
                $runcommand | Add-Member -NotePropertyName project -NotePropertyValue $cred.project
                $runcommand | Add-Member -NotePropertyName zone -NotePropertyValue $cred.zone
                $runcommand 
            }  until ($done -eq 1)
        }
    }
    if ($backup)
    {
        if (!($usertag))
        {
            $usertag = "googlebackupplan"
        }
        # learn all the SLTs
        $sltgrab = Get-AGMSLT
        foreach ($cred in $searchlist)
        {
            # we need to learn the srcid
            $credgrab = (Get-AGMLibCredentialSrcID | where-object {$_.credentialid -eq $cred.credentialid})
            if ($credgrab.srcid)
            {
                $srcid = $credgrab.srcid
                $diskpoolgrab = Get-AGMDiskpool -filtervalue cloudcredentialid=$srcid
                if ($diskpoolgrab)
                {
                    $poolname = $diskpoolgrab.name
                    $slpgrab = Get-AGMSLP -filtervalue performancepool=$poolname
                    if ($slpgrab)
                    {
                        $slpid = $slpgrab.id
                    }
                }
            }
            if ($slpid)
            {
                $done = 0
                do 
                {
                    $searchcommand = 'Get-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone
                    $runcommand = Invoke-Expression $searchcommand
                    $runcommand | Add-Member -NotePropertyName credentialid -NotePropertyValue $cred.credentialid
                    $runcommand | Add-Member -NotePropertyName applianceid -NotePropertyValue $cred.applianceid
                    $runcommand | Add-Member -NotePropertyName project -NotePropertyValue $cred.project
                    $runcommand | Add-Member -NotePropertyName zone -NotePropertyValue $cred.zone
                    $runcommand | Add-Member -NotePropertyName newgceinstances -NotePropertyValue 0
                    $runcommand | Add-Member -NotePropertyName newgceinstancebackup -NotePropertyValue 0
                    if ($runcommand.totalcount -gt 0)
                    {
                        foreach ($instance in $runcommand.items.vm)
                        {
                            # we always add the VM
                            $addappcommand = 'New-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -instanceid ' +$instance.instanceid
                            $newappcommand = Invoke-Expression $addappcommand
                            if ($newappcommand.count -eq 1)
                            {
                                $appid = $newappcommand.items.id
                                $runcommand.newgceinstances += 1 
                            }
                            $backupplancheck = $instance.tag | select-string $usertag
                            if ($backupplancheck)
                            {
                                # remove the leadering  and trailing { and }
                                $taglist = $instance.tag.Substring(1,$instance.tag.Length-2).Split(",")
                                # now for the backup tag
                                foreach ($tag in $taglist)
                                {
                                    $name = $tag.trim().split("=") | Select-object -First 1
                                    $value = $tag.trim().split("=") | Select-object -skip 1
                                    $sltid = ""
                                    # if the tag name is googlebackupplan we can protect it
                                    if ($name | select-string $usertag)
                                    {
                                        if ($sltgrab | where-object {$_.name -eq $value})
                                        {
                                            $sltid = ($sltgrab | where-object {$_.name -eq $value}).id
                                        }
                                        if (($sltid) -and ($slpid) -and ($appid))
                                        {
                                                $newsla = 'New-AGMSLA -appid ' +$appid +' -sltid ' +$sltid +' -slpid ' +$slpid
                                                $newsla = Invoke-Expression $newsla
                                                $runcommand.newgceinstancebackup += 1 
                                        }
                                    }
                                }
                            }
                        }
                        if ($runcommand.totalcount -lt 51)
                        {
                            $done = 1
                        }
                    }
                    else 
                    {
                        $done = 1
                    }
                    $runcommand 
                }  until ($done -eq 1)
            }
        }
    }
}
