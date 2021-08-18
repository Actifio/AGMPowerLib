Function Import-AGMLibSLT([string]$filename) 
{
    <#
    .SYNOPSIS
    Imports Policy Templates

    .EXAMPLE
    Import-AGMLibSLT -filename outfile.json
    Imports all SLTs from a file called outfile.json

    .DESCRIPTION
    A function to import Policy Templates

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
