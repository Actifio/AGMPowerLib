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
   else 
   {
       $sessiontest = (Get-AGMSession).session_id
       if ($sessiontest -ne $AGMSESSIONID)
       {
           Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
           return
       }
   }
   $credentialgrab = Get-AGMCredential  | Select-Object sources
   if ($credentialgrab.sources)
   {
        $printarray = @()
       foreach ($source in $credentialgrab.sources)
       {
            $appliancename = $source.appliance 
            $printarray += [pscustomobject]@{
                credentialname = $source.name
                appliancename = $appliancename.name
                srcid = $source.srcid
            }
       }
   }
   $printarray | Sort-Object credentialname,appliancename
}