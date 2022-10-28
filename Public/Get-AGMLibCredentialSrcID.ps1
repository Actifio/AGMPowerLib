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
        $sessiontest
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






