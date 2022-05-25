Function New-AGMLibGCEInstanceDiscovery ([string]$discoveryfile,[switch]$addall) 
{
     <#
    .SYNOPSIS
    Uses a pre-prepared CSV list of cloud credential IDs, appliance IDs, projects and zones to discover new GCE Instances

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -sourcefile credentials.csv -addall

    Adds all new GCE Instances discovered in the nominated projects and zones as unmanaged applications

    .EXAMPLE
    New-AGMLibGCEInstanceDiscovery -sourcefile credentials.csv -tagged

    Adds all new GCE Instances discovered in the nominated projects and zones that are tagged with googlebackupplan

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
    
    if (!($discoveryfile))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a source csv file correctly formatted as per the help for this function using: -discoveryfile xxxx.csv"
        return;
    }
    $searchlist = Import-Csv -Path $discoveryfile

    if ($addall)
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
    if ($tagged)
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
                        # command to find tag needs to go here
                        $addcommand = 'New-AGMCloudVM -credentialid ' +$cred.credentialid +' -clusterid ' +$cred.applianceid +' -project ' +$cred.project +' -zone ' +$cred.zone +' -instanceid ' +$instance.instanceid
                        $runcommand = Invoke-Expression $addcommand
                        # command to protect added VM here
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
}
