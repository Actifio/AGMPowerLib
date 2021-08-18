Function Export-AGMLibSLT([string]$sltids,[string]$filename,[switch][alias("a")]$all) 
{
    <#
    .SYNOPSIS
    Exports Policy Templates

    .EXAMPLE
    Export-AGMLibSLT -all -filename outfile.json
    Exports all SLTs to a file called outfile.json

    .DESCRIPTION
    A function to export Policy Templates

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

    if ((!($sltids)) -and (!($all)))
    {
        
        Clear-Host
        Write-Host "This function is used to export Policy Templates.  Please choose from the following list:"
        Write-Host ""
        write-host "1`: Export them all (default)"
        Write-Host "2`: Select specific templates"
        write-host "3`: Exit"
        Write-Host ""
        # ask the user to choose
        While ($true) 
        {
            Write-host ""
            $listmax = 3
            [int]$userselection = Read-Host "Please select from this list [1-$listmax]"
            if ($userselection -lt 1 -or $userselection -gt $listmax)
            {
                Write-Host -Object "Invalid selection. Please enter a number in range [1-$listmax)]"
            } 
            else
            {
                break
            }
        }
        if (($userselection -eq 1) -or ($userselection -eq ""))
        {  
            $all = $true
        }
        if ($userselection -eq 2)
        { 
            $sltgrab = Get-AGMSLT -sort name:asc
            $sltgrab | select-object id,name | format-table
            $sltids = read-host "Please enter a comma separated list of SLT IDs that you want to export"
        }
        
        if ($userselection -eq 3) 
        {  
            return
        }


        if (!($filename))
        { 
            $filename = Read-Host "Please supply the name of a file to write the exported Policy Templates to, or press enter to export to the screen"
        }
        Clear-Host
        Write-Host "Guided selection is complete.  The values entered resulted in the following command:"
        Write-Host ""
        Write-Host -nonewline "Export-AGMLibSLT"  
        if ($all) { Write-Host -nonewline " -all" }
        if ($filename) { Write-Host -nonewline " -filename $filename" }
        if ($sltids) { Write-Host -nonewline " -sltids `"$sltids`"" }
        Write-Host ""
        Write-Host "1`: Run the command now"
        Write-Host "2`: Exit without running the command (default)"
        $appuserchoice = Read-Host "Please select from this list (1-2)"
        if ($appuserchoice -eq "") { $appuserchoice = 2}
        if ($appuserchoice -eq 2)
        {
            return
        }
    }


    if ($all)
    {
        $sltidlist = Get-AGMSLT | select-object id
        # need to handle 0 
        if ($sltidlist.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any SLTs."
            return
        }
        if ($sltidlist.id.count -eq 1)
        {
            $sltids = $sltidlist.id
        }
        else 
        {
            $sltids = $sltidlist.id -join ","
        }
        
    }


    
    $json = '{ "ids" : [' +$sltids  +']}'
    $sltexportgrab = Post-AGMAPIData  -endpoint /slt/export -body $json

    if (!($filename))
    {
        $sltexportgrab | Convertto-Json -depth 7 
    }
    else {
        $sltexportgrab | Convertto-Json -depth 7 | Out-File -FilePath $filename 
    }


}