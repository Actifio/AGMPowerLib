Function Get-AGMLibContainerYAML ([string]$imagename)
{
    <#
    .SYNOPSIS
    Displays the YAML for a container mount

    .EXAMPLE
    Get-AGMLibContainerYAML 
    You will be prompted for ImageID

    .EXAMPLE
    Get-AGMLibContainerYAML 54433520
    To display the YAML for Image 54433520

    .EXAMPLE
    Get-AGMLibContainerYAML 54433520
    To display the YAML for Image 54433520

    .EXAMPLE
    Get-AGMLibContainerYAML -imagename Image_25355628
    To display the YAML for Image_25355628

    .DESCRIPTION
    A function to display the YAML for a container mount

    #>


    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }
    $sessiontest = Get-AGMVersion
    if (!($sessiontest.summary))
    {
        Get-AGMErrorMessage -messagetoprint "AGM session has expired. Please login again using Connect-AGM"
        return
    }
    

    if ($imagename)
    {
        $imageidgrab = Get-AGMImage -filtervalue backupname=$imagename 
        if ($imageidgrab.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Could not determine an image ID for $imagename"
            return
        }
        else 
        {
            $imageid = ($imageidgrab).id
        }
    }

    if (!($imageid))
    {
        $imageid = Read-host "Image ID"
    }

    $yamlgrab = (Get-AGMImage -id $imageid).yaml
    $yamlgrab
    
}
