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


Function New-AGMLibGCEInstanceDiscovery ([string]$discoveryfile,[switch]$nobackup,[switch]$backup,[string]$usertag,[string]$credentialid,[string]$sltid,[string]$sltname,[switch]$bootonly,[string]$applianceid,[string]$project,[string]$zone,[switch]$textoutput,[decimal]$limit) 
{
     <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of cloud credential IDs, appliance IDs, projects and zones to discover new GCE Instances

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -sourcefile credentials.csv -nobackup

    Adds all new GCE Instances discovered in the nominated projects and zones as unmanaged applications

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -sourcefile credentials.csv -backup

    Adds all new GCE Instances discovered in the nominated projects and zones and protects any that have a valid template name

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -sourcefile credentials.csv -backup -boot

    Adds all new GCE Instances discovered in the nominated projects and zones and protects only the boot drive or any that have a valid template name

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -sourcefile credentials.csv -backup -usertag "corporatepolicy"

    Adds all new GCE Instances discovered in the nominated projects and zones and protects any that have a label named corporatepolicy and a valid template name

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -credentialid 259643 -applianceid 141805487622 -projectid avwservicelab1 -zone australia-southeast1-b -usertag backupplan -backup

    Instead of using a discovery file the four required variables are specified by the user.

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

    The default is to fetch 5 Instances at a time.  You can change this with -limit.  You may need to specify a larger timeout when running Connect-AGM
    You can also manually supply credentialid, applianceid, project and zone rather than using a CSV file

    If the following is specified then discovery will occur with no backup plans being applied:
    -nobackup

    If the following are specified in combination then all instances will have a backup plan applied to it:
    -backup -sltname "<name"
    -backup -sltid <slt ID learned with Get-AGMSLT>
    If the following is added then only boot disks will be protected:
    -bootonly
    If you want to use a label to determine what template is used, then on the Instance set a label 'backupplan' where the value is:
    - A valid template name
    - ignored  <-- If this is detected then the application will be added as ignored
    - unmanaged <-- If this is detected then the application will be added as unmanaged

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
    if (!($limit)) { $limit = 5}
    $offset = 0

    if ($sltid)
    {
        $sltgrab = Get-AGMSLT $sltid
        if ($sltgrab.id.count -ne 1)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find an SLT with ID $sltid"
            return;
        }
    }
    if ($sltname)
    {
        $sltgrab = Get-AGMSLT -filtervalue name=$sltname
        if ($sltgrab.id.count -ne 1)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find an SLT with name $sltname"
            return;
        }
        $sltid = $sltgrab.id
    }


    if ($nobackup)
    {
        foreach ($cred in $searchlist)
        {
            $done = 0
            do 
            {
                $searchcommand = 'Get-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -limit ' +$limit
                if ($textoutput)
                {
                    $ct = Get-Date
                    write-host "$ct Running" $searchcommand
                }
                $newvmcommand = Invoke-Expression $searchcommand
                if ($newvmcommand.totalcount -gt 0)
                {
                    $offset += 1
                    $instancelist = ""
                    foreach ($instance in $newvmcommand.items.vm)
                    {
                        $instancelist = $instancelist + "," +$instance.instanceid  
                    }
                    # remove leading comma
                    $instancelist = $instancelist.substring(1)    
                    $addcommand = 'New-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -instanceid "' +$instancelist +'"'
                    if ($textoutput)
                    {
                        $ct = Get-Date
                        write-host "$ct Running" $addcommand
                    }
                    $addvmcommand = Invoke-Expression $addcommand
                    $addvmcommand | Add-Member -NotePropertyName credentialid -NotePropertyValue $cred.credentialid
                    $addvmcommand | Add-Member -NotePropertyName applianceid -NotePropertyValue $cred.applianceid
                    $addvmcommand | Add-Member -NotePropertyName project -NotePropertyValue $cred.project
                    $addvmcommand | Add-Member -NotePropertyName zone -NotePropertyValue $cred.zone
                    $addvmcommand 
                }
                else 
                {
                    $done = 1
                }
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
            $credgrab = (Get-AGMLibCredentialSrcID | where-object {($_.credentialid -eq $cred.credentialid) -and ($_.applianceid -eq $cred.applianceid)})
            if ($credgrab.srcid)
            {
                $srcid = $credgrab.srcid
                $diskpoolgrab = Get-AGMDiskpool -filtervalue cloudcredentialid=$srcid
                if ($diskpoolgrab)
                {
                    $poolname = $diskpoolgrab.name
                    $slpgrab = Get-AGMSLP -filtervalue "performancepool=$poolname&clusterid=$applianceid" -limit 1
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
                    $searchcommand = 'Get-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -limit ' +$limit
                    if ($textoutput)
                    {
                        $ct = Get-Date
                        write-host "$ct Running" $searchcommand
                    }
                    $newvmcommand = Invoke-Expression $searchcommand
                    $newvmcommand | Add-Member -NotePropertyName credentialid -NotePropertyValue $cred.credentialid
                    $newvmcommand | Add-Member -NotePropertyName applianceid -NotePropertyValue $cred.applianceid
                    $newvmcommand | Add-Member -NotePropertyName project -NotePropertyValue $cred.project
                    $newvmcommand | Add-Member -NotePropertyName zone -NotePropertyValue $cred.zone
                    $newvmcommand | Add-Member -NotePropertyName newgceinstances -NotePropertyValue 0
                    $newvmcommand | Add-Member -NotePropertyName newgceinstancebackup -NotePropertyValue 0
                    if ($newvmcommand.totalcount -gt 0)
                    {
                        $offset += 1
                        # we need the instance data
                        $matchinginstances = $newvmcommand.items.vm
                        $instancelist = ""
                        foreach ($instance in $newvmcommand.items.vm)
                        {
                            $instancelist = $instancelist + "," +$instance.instanceid  
                        }
                        # remove leading comma
                        if ($instancelist)
                        {
                            $instancelist = $instancelist.substring(1) 
                        }
                        if ($instancelist -ne "")
                        {
                       
                            $addappcommand = 'New-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -instanceid "' +$instancelist +'"'
                            if ($textoutput)
                            {
                                $ct = Get-Date
                                write-host "$ct Running" $addappcommand
                            }
                            $newappcommand = Invoke-Expression $addappcommand
                            if ($newappcommand.count -ge 1)
                            {
                                # here we build $newslalist which we process afterwards.
                                $newslalist = @()
                                foreach ($instance in $newappcommand.items)
                                {
                                    $appid = $instance.id
                                    $newvmcommand.newgceinstances += 1 
                                    $newapphostuniquename = $instance.host.sources.uniquename
                                    $taggrab = $matchinginstances | where-object {$_.instanceid -eq $newapphostuniquename } | Select-Object tag
                                    $backupplancheck = $taggrab.tag | select-string $usertag
                                    # if user supplied default sltid then use that
                                    if ((!($backupplancheck)) -and ($sltid))
                                    {
                                        if (($sltid) -and ($slpid) -and ($appid))
                                        {
                                            $newslalist += [pscustomobject]@{
                                                appid = $appid
                                                sltid = $sltid
                                                slpid = $slpid
                                            }
                                            $newvmcommand.newgceinstancebackup += 1 
                                        }
                                    }
                                    if ($backupplancheck)
                                    {
                                        # remove the leadering  and trailing { and }
                                        $taglist = $taggrab.tag.substring(1,$taggrab.tag.Length-2).Split(",")
                                        # now for the backup tag
                                        foreach ($tag in $taglist)
                                        {
                                            $name = $tag.trim().split("=") | Select-object -First 1
                                            $value = $tag.trim().split("=") | Select-object -skip 1
                                            $sltid = ""
                                            # if the tag name is googlebackupplan we can protect it
                                            if ($name | select-string $usertag)
                                            {
                                                if ($value -eq "ignored")
                                                {
                                                    $jsonbody = '{"ignore":true}'
                                                    $appid = $_.appid
                                                    Put-AGMAPIData  -endpoint /application/$appid -body $jsonbody
                                                }
                                                elseif ($value -ne "unmanaged")
                                                {
                                                    if ($sltgrab | where-object {$_.name -eq $value})
                                                    {
                                                        $sltid = ($sltgrab | where-object {$_.name -eq $value}).id
                                                    }
                                                    if (($sltid) -and ($slpid) -and ($appid))
                                                    {
                                                        $newslalist += [pscustomobject]@{
                                                            appid = $appid
                                                            sltid = $sltid
                                                            slpid = $slpid
                                                        }
                                                        $newvmcommand.newgceinstancebackup += 1 
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                if ( $((get-host).Version.Major) -gt 5 )
                                {
                                    if ($bootonly)
                                    {
                                        $jsonbody = '{"type":"boot"}'
                                        $newslalist | ForEach-Object {
                                            $appid = $_.appid
                                            Put-AGMAPIData  -endpoint /application/$appid/memberrule -body $jsonbody
                                        }
                                    }
                                    if ($AGMToken)
                                    {
                                        $newslalist | ForEach-Object -parallel {
                                            $newsla = 'New-AGMSLA -appid ' +$_.appid +' -sltid ' +$_.sltid +' -slpid ' +$_.slpid
                                            if ($textoutput)
                                            {
                                                $ct = Get-Date
                                                write-host "$ct Running" $newsla
                                            }
                                            $agmip = $using:agmip 
                                            $AGMToken = $using:AGMToken 
                                            $AGMSESSIONID = $using:AGMSESSIONID
                                            New-AGMSLA -appid $_.appid -sltid $_.sltid -slpid $_.slpid
                                            start-sleep -seconds 5
                                        } -ThrottleLimit $limit
                                    }
                                    else 
                                    {
                                        $newslalist | ForEach-Object -parallel {
                                            $newsla = 'New-AGMSLA -appid ' +$_.appid +' -sltid ' +$_.sltid +' -slpid ' +$_.slpid
                                            if ($textoutput)
                                            {
                                                $ct = Get-Date
                                                write-host "$ct Running" $newsla
                                            }
                                            $agmip = $using:agmip  
                                            $AGMSESSIONID = $using:AGMSESSIONID
                                            $IGNOREAGMCERTS = $using:IGNOREAGMCERTS
                                            New-AGMSLA -appid $_.appid -sltid $_.sltid -slpid $_.slpid
                                            start-sleep -seconds 5
                                        } -ThrottleLimit $limit
                                    }
                                    
                                }
                                else {
                                    if ($bootonly)
                                    {
                                        $jsonbody = '{"type":"boot"}'
                                        $newslalist | ForEach-Object {
                                            $appid = $_.appid
                                            Put-AGMAPIData  -endpoint /application/$appid/memberrule -body $jsonbody
                                        }
                                    }
                                    $newslalist | ForEach-Object {
                                        $newsla = 'New-AGMSLA -appid ' +$_.appid +' -sltid ' +$_.sltid +' -slpid ' +$_.slpid
                                        if ($textoutput)
                                        {
                                            $ct = Get-Date
                                            write-host "$ct Running" $newsla
                                        }
                                        New-AGMSLA -appid $_.appid -sltid $_.sltid -slpid $_.slpid
                                    } 
                                }
                            }
                        }
                    }
                    else 
                    {
                        $done = 1
                    }
                    $newvmcommand 
                }  until ($done -eq 1)
                if ($textoutput)
                {
                    $ct = Get-Date
                    write-host "$ct Complete"
                }
            }
        }
    }
}
