Function Import-AGMLibSLT([string]$filename,[string]$bucket,[string]$objectname) 
{
    <#
    .SYNOPSIS
    Imports Policy Templates

    .EXAMPLE
    Import-AGMLibSLT -filename outfile.json
    Imports all SLTs from a file called outfile.json

    .EXAMPLE
    Import-AGMLibSLT -bucket avwlab2testbucket -objectname itsthename.json1
    Imports the contents of a JSON file in a GCS bucket.   
    This presumes the Google Cloud Tools for PowerShell Module has been installed and that the user has access to the bucket

    .DESCRIPTION
    A function to import Policy Templates

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
    
    if ($bucket) 
    {
        if (!($objectname))
        {
            $objectname = Read-host "Please supply the object name in GCS of the exported templates"
        }
        if ($objectname)
        {
            $json = Read-GcsObject -bucket $bucket -objectname $objectname
        }
        if ($json)
        {
            Post-AGMAPIData  -endpoint /slt/import -body $json
        }
        return
    }


    if (!($filename))
    {
        $filename = Read-host "Please supply the filename of the exported templates"
    }
    if ( Test-Path $filename )
    {
        $json = Get-Content -Path $filename
    }
    else
    {
        Get-AGMErrorMessage -messagetoprint "The file named $filename could not be found."
        return
    }
    Post-AGMAPIData  -endpoint /slt/import -body $json
}
