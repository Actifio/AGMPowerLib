Function Set-AGMLibImage ([array]$imagelist,$filename) 
{
    <#
    .SYNOPSIS
    Sets the label for a range of images using either an array or CSV file

    .EXAMPLE
    Set-AGMLibImage -imagelist $imagelist 

    .DESCRIPTION
    We can create an imagelist several ways.   This method literally gets every image
    $imagelist = Get-AGMImage | select id,backupname,label
    We could update the label field like this:
       foreach ($image in $imagelist) { $image.label = "Needs Checking" }
    Then run the command:   Set-AGMLibImage -imagelist $imagelist 
    We could then export  like this:    $imagelist | Export-Csv -Path images.csv
    Then edit the file and when reading save the CSV and run this command:  
    Set-AGMLibImage -filename images.csv
    #>

    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    else 
    {
        $sessiontest = (Get-AGMSession).session_id
        if ($sessiontest -ne $AGMSESSIONID)
        {
            Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
            return
        }
    }
    if ((!($imagelist)) -and (!($filename)))
    {
        Write-host "we need either -imagelist or -filename"
    }
    if ($filename)
    {
        if ([IO.File]::Exists($filename))
        {
            $imagelist = Import-Csv -Path $filename
        }
    }
    if ($imagelist)
    {
        if ((!($imagelist.id)) -or (!($imagelist.label)) -or (!($imagelist.backupname)))
        {
            Get-AGMErrorMessage -messagetoprint "The imagelist specified with -imagelist needs to contain the following fields:  id, backupname, label"
            return
        }
    }

    foreach ($image in $imagelist | where-object {$_.label.length -gt 0})
    {
        Set-AGMImage -id $image.id -label $image.label -imagename $image.backupname
    }

}
