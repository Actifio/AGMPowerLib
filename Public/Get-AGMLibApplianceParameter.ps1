Function Get-AGMLibApplianceParameter([string]$applianceid,[string]$param,[switch]$allparams,[switch]$slots) 
{
    <#
    .SYNOPSIS
    Fetches output of parameters from appliances.  This means we dont need access to the appliance to do this.
    We need to supply an ID for the relevant Appliance.
    You can learn the applianceid by running Get-AGMAppliance and using the value in the id field for the relevant appliance

    .EXAMPLE
    Get-AGMLibApplianceParameter -applianceid 1234 
    Display the value of all parameters for appliance with ID 1234

    .EXAMPLE
    Get-AGMLibApplianceParameter -applianceid 1234 -param maxsnapslots
    Display the value of the maxsnapslots parameter for appliance with ID 1234

    .EXAMPLE
    Get-AGMLibApplianceParameter -applianceid 1234 -slots
    Display the value of the commonly changed slot parameters for appliance with ID 1234

    .DESCRIPTION
    A function to get parameters

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
    
    # first we need an applianceid
    if (!($applianceid))
    {
        $appliancegrab = Get-AGMAppliance
        if ($appliancegrab.id.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any appliances with Get-AGMAppliance"
            return
        }
        if ($appliancegrab.id.count -eq 1)
        {
            $applianceid = $appliancegrab.id
            write-host "Applianceid is $applianceid"
            write-host ""
        }
        if ($appliancegrab.id.count -gt 1)
        {
            write-host ""
            write-host "Select which Appliance you wish to get parameters from"
            write-host ""
            $i = 1
            foreach ($appliance in $appliancegrab)
            { 
                $id = $appliance.id
                $name = $appliance.name
                Write-Host -Object "$i`: $name (applianceid: $id)"
                $i++
            }
            While ($true) 
            {
                Write-host ""
                $listmax = $appliancegrab.id.count
                [int]$appselection = Read-Host "Please select an appliance (1-$listmax)"
                if ($appselection -lt 1 -or $appselection -gt $listmax)
                {
                    Write-Host -Object "Invalid selection. Please enter a number in range [1-$($listmax)]"
                } 
                else
                {
                    break
                }
            }
            $applianceid =  $appliancegrab.id[($appselection - 1)]
        }
    } 
    
   
    if ($param)
    {
        Get-AGMAPIApplianceInfo -applianceid $applianceid -command "getparameter" -arguments "param=$param"
    }
    elseif ($slots)
    {
        $paramgrab = Get-AGMAPIApplianceInfo -applianceid $applianceid -command "getparameter" 
        if ($paramgrab.maxsnapslots)
        {
            $paramarray = @()
            $paramarray += [pscustomobject]@{
                maxsnapslots = $paramgrab.maxsnapslots
                reservedsnapslots = $paramgrab.reservedsnapslots
                snapshotonrampslots = $paramgrab.snapshotonrampslots
                maxstreamsnapslots = $paramgrab.maxstreamsnapslots
                reservedstreamsnapslots = $paramgrab.reservedstreamsnapslots
                streamsnaponrampslots = $paramgrab.streamsnaponrampslots
                maxvaultslots = $paramgrab.maxvaultslots
                reservedvaultslots = $paramgrab.reservedvaultslots
                onvaultonrampslots = $paramgrab.onvaultonrampslots
                maxlogtovaultslots = $paramgrab.maxlogtovaultslots
                reservedlogtovaultslots = $paramgrab.reservedlogtovaultslots
            }
        }
       $paramarray 
    }
    else 
    {
        Get-AGMAPIApplianceInfo -applianceid $applianceid -command "getparameter" 
    }
}