Function Get-AGMLibCredentialSrcID
{  
    <#
   .SYNOPSIS
   Get the src ID for a Cloud Credential 

   .EXAMPLE
   Get-AGMLibCredentialSrcID
   To list all source IDs


   .DESCRIPTION
   A function to get the source IDs for Cloud Credentials
   #>


   # its pointless procededing without a connection.
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
   
   $credentialgrab = Get-AGMCredential  
   if ($credentialgrab.sources)
    {
        $credarray = @()
        foreach ($credential in $credentialgrab)
        {
            foreach ($source in $credential.sources)
            {
                $appliancename = $source.appliance 
                $credarray += [pscustomobject]@{
                    appliancename = $appliancename.name
                    applianceid = $appliancename.clusterid
                    credentialname = $source.name
                    credentialid = $credential.id
                    srcid = $source.srcid
                }
            }
        }
    }
   $credarray | Sort-Object appliancename,credentialname
}






