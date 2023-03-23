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


Function New-AGMLibGCEInstanceDiscovery ([string]$discoveryfile,[switch]$nobackup,[switch]$backup,[string]$usertag,[string]$backupplanlabel,[string]$diskbackuplabel,[string]$metadatabackupplan,[string]$metadatadiskbackup,[string]$credentialid,[string]$sltid,[string]$sltname,[switch]$bootonly,[string]$applianceid,[string]$project,[string]$projectid,[string]$zone,[string]$filter,[switch]$textoutput,[decimal]$limit,[switch]$noparallel,[switch]$verbose,[switch]$gcloudsearch) 
{
     <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of cloud credential IDs, appliance IDs, projects and zones to discover new GCE Instances

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -discoveryfile credentials.csv -nobackup

    Adds all new GCE Instances discovered in the nominated projects and zones as unmanaged applications

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -discoveryfile credentials.csv -backup

    Adds all new GCE Instances discovered in the nominated projects and zones and protects any that have a valid template name

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -discoveryfile credentials.csv -backup -boot

    Adds all new GCE Instances discovered in the nominated projects and zones and protects only the boot drive or any that have a valid template name

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -discoveryfile credentials.csv -backup -backupplanlabel "corporatepolicy"

    Adds all new GCE Instances discovered in the nominated projects and zones and protects any that have a label named corporatepolicy and a valid template name

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -credentialid 259643 -applianceid 141805487622 -projectid avwservicelab1 -zone australia-southeast1-b -backupplanlabel backupplan -backup

    Instead of using a discovery file the four required variables are specified by the user.

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -credentialid 706606 -applianceid 144091747698 -project avwarglab1 -zone australia-southeast2-a -backupplanlabel backupplan -diskbackuplabel diskbackup -backup

    In this example the user uses two labels on each Compute Engine instance to determine backup handling.  -backupplanlabel backupplan means if the instance has a label of backupplan then use its value as the template name.  While -diskbackuplabel diskbackup means if the instance has a label of diskbackup and the value is bootonly then set bootonly backup on that instance. 


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

    Label management has two values that can be set:
     -backupplanlabel xxxx     If the instance has a label named xxxx then use its value as the template name.   If the value is 'ignored' or 'unmanaged' then do that instead
     -diskbackuplabel yyy      If the instance has a label of yyy and the value is bootonly then set bootonly backup on that instance.

    gcloudsearch parameter
    The search and addition of new instances will by default be done by the appliance service account.  This also means all discovered instances will be added to Backup and DR
    If you instead specify -gcloudsearch then the powershell service account will be used to search for new instances while the appliance service account will still be used to add them.   However only matching instances will be added.
    This also means the powershell service account also needs the Compute Viewer IAM role.

    Metatadata management has two values that can be set.  note that if you search for metadata then gcloudsearch switch is to true.  
    -metadatabackupplan xxxx     If the instance has metadata key named xxxx then use its value as the template name.   If the value is 'ignored' or 'unmanaged' then do that instead
    -metadatadiskbackup yyy      If the instance has metadata key named  yyy and the value is bootonly then set bootonly backup on that instance.

    Filter value search
    You can add two different filters if you want to force the onboarding of ignored or unmanaged instances that have already been discovered and you now want to apply a backup plan template
    -filter ignored      Will apply a backup plan to discovered instances that are marked as ignored
    -filter unmanaged      Will apply a backup plan to discovered instances that are unmanaged
    However the use of these filters may result in discovery looping endlessly if the onboarding state does not change.   So use filters with care.

    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    # verbose =  textoutput
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
    # if user wants to say projectid rather than project, we let them
    if ($projectid) { $project = $projectid}
    # rename usertag support
    if ($usertag) { $backupplanlabel = $usertag}

    # metadata searches need gcloud search enabled
    if ($metadatabackupplan) { $gcloudsearch = $true}
    if ($metadatadiskbackup) { $gcloudsearch = $true}

    #if user would rather not use a CSV file, we need all the stats
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
        Get-AGMErrorMessage -messagetoprint "Please supply a source csv file correctly formatted as per the help for this function using: -discoveryfile xxxx.csv or supply applianceid,credentialid,project and zone"
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

    if ($backup)
    {
        if ((!($sltid)) -and (!($backupplanlabel)) -and (!($metadatabackupplan)))
        {
            Get-AGMErrorMessage -messagetoprint "When specifying -backup either supply a default template with -sltid or -sltname and/or specify a -backupplanlabel"
            return;
        }
    }

    if ((!($backup)) -and (!($nobackup)))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify either -backup or -nobackup to determine whether discovered instances should be protected or not protected"
        return;
    }

    if (($backupplanlabel) -and ($metadatabackupplan))
    {
        Get-AGMErrorMessage -messagetoprint "Please dont specify both backupplanlabel and metadatabackupplan.  The use of only one choice is supported"
        return;
    }

    if ($filter)
    {
        # do not add filter on managed or you end up in endless loop.  This function cannot be used to change the SLA template of a managed instance
        if ($filter -ne "New" -and $filter -ne "Ignored" -and $filter -ne "Unmanaged" )
        {
            Get-AGMErrorMessage -messagetoprint "The Filter $filter is not valid.  Use either New, Ignored or Unmanaged"
            return
        }
    }
    if ((!$filter)) { $labelfilter = "-labels.actifio-role:*" } else { $labelfilter = 'labels.actifio-role:' +$filter +'*'}

    if ($backupplanlabel)
    {
        $backupplanlabelsearch = ' AND labels.' +$backupplanlabel +':*' 
    }
    if ($metadatabackupplan)
    {
        $metadatakeysearch = ' AND metadata.list(show="key"):' +$metadatabackupplan
    }
    


    if ($nobackup)
    {
        foreach ($cred in $searchlist)
        {
            $done = 0
            do 
            {
                if ($gcloudsearch)
                { 
                    # dont add filter search to this command or you could end up in endless loop, because unless you change the actifio-role you will keep finding the same VMs
                    $searchcommand = 'gcloud compute instances list --project ' +$cred.project +' --zones ' +$cred.zone +' --filter="(-labels.actifio-role:*' +$backupplanlabelsearch +$metadatakeysearch +')" --format="json(name,id,labels,metadata.items)" --limit 50 --verbosity error | ConvertFrom-Json'
                }
                else
                # dont add filter search to this command or you could end up in endless loop, because unless you change the actifio-role you will keep finding the same VMs
                {
                    $searchcommand = 'Get-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -limit ' +$limit                    
                }
                if ($textoutput)
                {
                    $ct = Get-Date
                    write-host "$ct Running" $searchcommand
                }
                $newvmcommand = Invoke-Expression $searchcommand
                if ($gcloudsearch)
                {
                    $totalcount = $newvmcommand.id.count
                }
                else {
                    $totalcount = $newvmcommand.totalcount
                }
                if ($totalcount -gt 0)
                {
                    $offset += 1
                    $instancelist = ""
                    if ($gcloudsearch)
                    {
                        # gcloud returns the instanceids in the id column
                        foreach ($instance in $newvmcommand.id) { $instancelist = $instancelist + "," +$instance }
                    }
                    else 
                    {
                        # platform returns the instance IDs in items.vms.instanceid
                        foreach ($instance in $newvmcommand.items.vm) { $instancelist = $instancelist + "," +$instance.instanceid }
                    }
                    # remove leading comma in our instance list
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

        # learn all the SLTs
        if ($textoutput)
        {
            $ct = Get-Date
            write-host "$ct Running Get-AGMSLT"
        }
        $sltgrab = Get-AGMSLT
        if ($textoutput)
        {
            $ct = Get-Date
            write-host "$ct Output:"
            $sltgrab
        }
        if ($textoutput)
        {
            $ct = Get-Date
            write-host "$ct Running Get-AGMSLP"
        }
        $slpgrab = Get-AGMSLP
        if ($textoutput)
        {
            $ct = Get-Date
            write-host "$ct Output:"
            $slpgrab
        }
        if ($textoutput)
        {
            $ct = Get-Date
            write-host "$ct Running Get-AGMLibCredentialSrcID"
        }
        $srccredgrab = Get-AGMLibCredentialSrcID
        if ($textoutput)
        {
            $ct = Get-Date
            write-host "$ct Output:"
            $credgrab
        }
        if ($textoutput)
        {
            $ct = Get-Date
            write-host "$ct Running Get-AGMDiskpool"
        }
        $diskpooldatagrab = Get-AGMDiskpool -filtervalue pooltype=cloud | Select-object name,@{N='srcid';E={$_.cloudcredential.sources.srcid}}
        if ($textoutput)
        {
            $ct = Get-Date
            write-host "$ct Output:"
            $diskpooldatagrab
        }
        foreach ($cred in $searchlist)
        {
            if ($textoutput)
            {
                $ct = Get-Date 
                write-host "$ct Processing this selection"
                $cred
            }
            # we need to learn the srcid
            $credgrab = ($srccredgrab | where-object {($_.credentialid -eq $cred.credentialid) -and ($_.applianceid -eq $cred.applianceid)})
            if ($credgrab.srcid)
            {
                $srcid = $credgrab.srcid
                $diskpoolgrab = $diskpooldatagrab | where-object {($_.srcid -eq $srcid)}
                if ($diskpoolgrab.name)
                {
                    $poolname = $diskpoolgrab.name
                    $slplookup = ($slpgrab | where-object {($_.performancepool -eq $poolname) -and ($_.clusterid -eq $cred.applianceid)})
                    if ($slplookup.id)
                    {
                        $slpid = $slplookup.id
                    }
                }
            }
            if ($slpid)
            {
                $done = 0
                do 
                {
                    if ($gcloudsearch)
                    {
                        $searchcommand = 'gcloud compute instances list --project ' +$cred.project +' --zones ' +$cred.zone +' --filter="(' +$labelfilter +$backupplanlabelsearch +$metadatakeysearch +')" --format="json(name,id,labels,metadata.items)" --limit=50 --verbosity error | ConvertFrom-Json'
                    }
                    else 
                    {
                        if ($filter)
                        {
                            $searchcommand = 'Get-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -limit ' +$limit +' -filter '+$filter
                        }
                        else 
                        {
                            $searchcommand = 'Get-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -limit ' +$limit
                        }
                    }
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

                    $progressarray = [pscustomobject]@{
                        newgceinstances = 0
                        newgceinstancebackup = 0
                    }

                    if ($gcloudsearch)
                    {
                        $totalcount = $newvmcommand.id.count
                    }
                    else {
                        $totalcount = $newvmcommand.totalcount
                    }
                    if ($totalcount -gt 0)
                    {
                        $offset += 1
                        $instancelist = ""
                        if ($gcloudsearch)
                        {
                            # gcloud returns the instanceids in the id column
                            foreach ($instance in $newvmcommand.id) { $instancelist = $instancelist + "," +$instance }
                            $matchinginstances = $newvmcommand
                        }
                        else 
                        {
                            # platform returns the instance IDs in items.vms.instanceid
                            $matchinginstances = $newvmcommand.items.vm
                            foreach ($instance in $newvmcommand.items.vm) { $instancelist = $instancelist + "," +$instance.instanceid }
                        }
                        # remove leading comma in our instance list
                        if ($instancelist) { $instancelist = $instancelist.substring(1) }
                        if ($instancelist -ne "")
                        {
                            $addappcommand = 'New-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -instanceid "' +$instancelist +'"'
                            if ($textoutput)
                            {
                                $ct = Get-Date
                                write-host "$ct Running" $addappcommand
                            }
                            $newappcommand = Invoke-Expression $addappcommand
                            if ($textoutput)
                            {
                                $ct = Get-Date
                                write-host "$ct Addition of the VM got the following output:"
                                if ($newappcommand.count) { $newappcommand.count }
                                if ($newappcommand.items) { $newappcommand.items }
                                else
                                {
                                    $newappcommand
                                }
                                write-host ""
                            }                         
                            if ($newappcommand.errormessage)
                            {
                                $newappcommand.errormessage
                                $done = 1
                            }
                            if ($newappcommand.count -ge 1)
                            {
                                # here we build $newslalist which we process afterwards.   This step adds the VM...  we protect it in the next step
                                $newslalist = @()
                                foreach ($instance in $newappcommand.items)
                                {
                                    $appid = $instance.id
                                    $progressarray.newgceinstances += 1 
                                    $newapphostuniquename = $instance.host.sources.uniquename
                                    if ($gcloudsearch)
                                    {
                                        $instancelabels = $matchinginstances | where-object {$_.id -eq $newapphostuniquename } | Select-Object labels
                                        if ($textoutput)
                                        {
                                            $ct = Get-Date
                                            write-host "Label check found: $instancelabels "
                                        }
                                        if ($metadatabackupplan)
                                        {
                                            $instancemetadata = $matchinginstances | where-object {$_.id -eq $newapphostuniquename } | Select-Object metadata
                                            if ($textoutput)
                                            {
                                                $ct = Get-Date
                                                write-host "$ct found metadata"
                                                $instancemetadata
                                            }
                                            if ($instancemetadata)
                                            {
                                                $backupplancheck = ($instancemetadata.metadata.items | Where-Object {$_.key -eq $metadatabackupplan}).value
                                                if ($textoutput)
                                                {
                                                    $ct = Get-Date
                                                    write-host "$ct backupplan check found $backupplancheck in metadata"
                                                }
                                            }
                                        }
                                        if ($metadatadiskbackup)
                                        {
                                            $instancemetadata = $matchinginstances | where-object {$_.id -eq $newapphostuniquename } | Select-Object metadata
                                            if ($instancemetadata)
                                            {
                                                $diskbackuplabelcheck = ($instancemetadata.metadata.items | Where-Object {$_.key -eq $metadatadiskbackup}).value
                                                if ($textoutput)
                                                {
                                                    $ct = Get-Date
                                                    write-host "$ct diskbackup check found $diskbackuplabelcheck in metadata"
                                                }
                                            }
                                        }
                                        if (($instancelabels) -and ($backupplanlabel))
                                        {
                                            $backupplancheck = $instancelabels.labels.$backupplanlabel
                                            if ($textoutput)
                                            {
                                                $ct = Get-Date
                                                write-host "$ct backupplan check found $backupplancheck in labels"
                                            }
                                        }
                                        if (($instancelabels) -and ($diskbackuplabel))
                                        {
                                            $diskbackuplabelcheck = $instancelabels.labels.$diskbackuplabel
                                            if ($textoutput)
                                            {
                                                $ct = Get-Date
                                                write-host "$ct diskbackup check found $diskbackuplabelcheck in labels"
                                            }
                                        }
                                    }
                                    else
                                    {
                                        $labelgrab = $matchinginstances | where-object {$_.instanceid -eq $newapphostuniquename } | Select-Object tag
                                        if ($backupplanlabel)
                                        {
                                            $backupplancheck = $labelgrab.tag | select-string $backupplanlabel
                                        }
                                        if ($diskbackuplabel)
                                        {
                                            $diskbackuplabelcheck = $labelgrab.tag | select-string $diskbackuplabel
                                        }
                                    }
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
                                            $progressarray.newgceinstancebackup += 1 
                                        }
                                    }
                                    if (($backupplancheck) -and (!($gcloudsearch)))
                                    {
                                        # remove the leadering  and trailing { and }
                                        $labellist = $labelgrab.tag.substring(1,$labelgrab.tag.Length-2).Split(",")
                                        # now for the backup tag
                                        foreach ($label in $labellist)
                                        {
                                            $name = $label.trim().split("=") | Select-object -First 1
                                            $value = $label.trim().split("=") | Select-object -skip 1
                                            # if the label name is googlebackupplan we can protect it
                                            if ($name | select-string $backupplanlabel)
                                            {
                                                $labelsltid = ""
                                                if ($value -eq "ignored")
                                                {
                                                    $jsonbody = '{"ignore":true}'
                                                    Put-AGMAPIData  -endpoint /application/$appid -body $jsonbody
                                                }
                                                elseif ($value -ne "unmanaged")
                                                {
                                                    if ($sltgrab | where-object {$_.name -eq $value})
                                                    {
                                                        $labelsltid = ($sltgrab | where-object {$_.name -eq $value}).id
                                                    }
                                                    elseif ($sltid)
                                                    {
                                                        $labelsltid = $sltid
                                                    }
                                                    if (($labelsltid) -and ($slpid) -and ($appid))
                                                    {
                                                        $newslalist += [pscustomobject]@{
                                                            appid = $appid
                                                            sltid = $labelsltid
                                                            slpid = $slpid
                                                        }
                                                        $progressarray.newgceinstancebackup += 1 
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    if (($backupplancheck) -and ($gcloudsearch))
                                    {
                                        if ($backupplancheck -eq "ignored")
                                        {
                                            $jsonbody = '{"ignore":true}'
                                            Put-AGMAPIData  -endpoint /application/$appid -body $jsonbody
                                        }
                                        elseif ($backupplancheck -ne "unmanaged")
                                        {
                                            if ($sltgrab | where-object {$_.name -eq $backupplancheck})
                                            {
                                                $labelsltid = ($sltgrab | where-object {$_.name -eq $backupplancheck}).id
                                            }
                                            elseif ($sltid)
                                            {
                                                $labelsltid = $sltid
                                            }
                                            if (($labelsltid) -and ($slpid) -and ($appid))
                                            {
                                                $newslalist += [pscustomobject]@{
                                                    appid = $appid
                                                    sltid = $labelsltid
                                                    slpid = $slpid
                                                }
                                                $progressarray.newgceinstancebackup += 1 
                                            }
                                        }
                                    }
                                    # if the user is using a label as a hint as to whethe we do boot only per instance
                                    if ($diskbackuplabelcheck)
                                    {
                                        if ($gcloudsearch) 
                                        {
                                            if ($diskbackuplabelcheck -eq "bootonly")
                                            {
                                                $newslalist | where-object { $_.appid -eq $appid } | Add-Member -MemberType NoteProperty -Name diskbackup -Value "bootonly"
                                            }
                                        }
                                        else 
                                        {
                                           # remove the leadering  and trailing { and }
                                           $labellist = $labelgrab.tag.substring(1,$labelgrab.tag.Length-2).Split(",")
                                           # now look for the  diskbackuplabel 
                                           foreach ($label in $labellist)
                                           {
                                               $name = $label.trim().split("=") | Select-object -First 1
                                               $value = $label.trim().split("=") | Select-object -skip 1
                                               # if we find diskbackuplabel and its value is bootonly we use it.   In future we could add more logic here
                                               if (($name | select-string $diskbackuplabel) -and ($value -eq "bootonly"))
                                               {
                                                   $newslalist | where-object { $_.appid -eq $appid } | Add-Member -MemberType NoteProperty -Name diskbackup -Value "bootonly"
                                               }
                                           }
                                        }
                                    }
                                }
                                # bootonly routine where user is specifying bootonly via label or for all VMs.   We do this per VM
                                $newslalist | ForEach-Object {
                                    $appid = $_.appid
                                    $diskbackuprule = $_.diskbackup
                                    if (($diskbackuprule -eq "bootonly") -or ($bootonly))
                                    {
                                        $jsonbody = '{"type":"boot"}'
                                        Put-AGMAPIData  -endpoint /application/$appid/memberrule -body $jsonbody
                                    }
                                }
                                # now we protect the VMs 
                                if ( ($((get-host).Version.Major) -gt 5 ) -and (!($noparallel)))
                                {
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
                    if ($gcloudsearch)
                    {
                        $newvmcommand
                        $progressarray
                    }
                    else {
                        $newvmcommand | Add-Member -NotePropertyName newgceinstances -NotePropertyValue $progressarray.newgceinstances
                        $newvmcommand | Add-Member -NotePropertyName newgceinstancebackup -NotePropertyValue $progressarray.newgceinstancebackup
                        $newvmcommand 
                    }
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
