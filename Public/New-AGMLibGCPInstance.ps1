Function New-AGMLibGCPInstance ([string]$appid,[string]$imageid,[string]$imagename,[string]$credentialid,[string]$projectname,[string]$zone,[string]$instancename,[string]$machinetype,[string]$serviceaccount,[string]$networktags,[string]$labels,[string]$nic0network,[string]$nic0subnet,[string]$nic0externalip,[string]$nic0internalip,[string]$nic1network,[string]$nic1subnet,[string]$nic1externalip,[string]$nic1internalip,[string]$poweronvm) 
{
    <#
    .SYNOPSIS
    Mounts a PD Snapshot as a new GCP Instance (VM)

    .EXAMPLE
    New-AGMLibGCPInstance -imageid 56410933 -credentialid 1234 -zone australia-southeast1-c -projectname myproject -instancename avtest21 -machinetype e2-micro -networktags "http-server,https-server" -labels "dog:cat,sheep:cow" -nic0network "https://www.googleapis.com/compute/v1/projects/projectname/global/networks/default" -nic0subnet "https://www.googleapis.com/compute/v1/projects/projectname/regions/australia-southeast1/subnetworks/default" -nic0externalip auto -nic0internalip "10.152.0.200" -poweronvm false

    This mounts the specified imageid 56410933

    .EXAMPLE
    New-AGMLibGCPInstance -appid 1234 -credentialid 1234 -zone australia-southeast1-c -projectname myproject -instancename avtest21 -machinetype e2-micro -networktags "http-server,https-server" -labels "dog:cat,sheep:cow" -nic0network "https://www.googleapis.com/compute/v1/projects/projectname/global/networks/default" -nic0subnet "https://www.googleapis.com/compute/v1/projects/projectname/regions/australia-southeast1/subnetworks/default" -nic0externalip auto -nic0internalip "10.152.0.200" -poweronvm false

    This mounts the most recent snapshot from appid 1234

    .DESCRIPTION
    To learn which Applications are suitable use this command:
    Get-AGMApplication -filtervalue "apptype=GCPInstance&managed=True" | select id,appname

    To learn which Cloud Credentials are available use this command (use the srcid as the credential ID):
    Get-AGMCredential

    To learn the image ID or image name, you could use this command:
    Get-AGMImage -filtervalue "apptype=GCPInstance&jobclass=snapshot" | select appname,id,name,consistencydate,diskpool | ft
    
    There are many parameters that need to be supplied:

    -appid           The application ID of the source GCP Instance you want to mount.  If you use this you don't need to specify an image ID or name.   It will use the latest snapshot of that application.
    -imageid         You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image)
    -imagename       You need to supply either the imageid or the imagename or both (or specify -appid instead to get the latest image)
    -credentialid    Learn this with Get-AGMCredential.  The credentialid is the srcid.
    -serviceaccount  The service account that is being used to request the instance creation.  This is optional.  Otherwise it will use the account from the cloud credential
    -projectname     This is the unique Google Project name
    -zone            This is the GCP Zone such as: australia-southeast1-c
    -instancename    This is the name of the new instance that will be created.   It needs to be unique in that project
    -machinetype     This is the GCP instance machine type such as:  e2-micro
    -networktags     Comma separate as many tags as you have, for instance:   -networktags "http-server,https-server"   
    -labels          Labels are key value pairs.   Separate key and value with colons and each label with commas.   For example:   -labels "dog:cat,sheep:cow"
    -nic0network     The network name in URL format for nic0
    -nic0subnet      The subnet name in URL format for nic0
    -nic0externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic0 is 'none'
    -nic0internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic0 will be auto assigned.   
    -poweronvm       By default the new GCE Instance will be powered on.   If you want it to be created but left powered off, then specify: -poweronvm false
                     There is no need to specify: -poweronvm true 

    Optionally you can request a second NIC:
    -nic1network     The network name in URL format for nic1
    -nic1subnet      The subnet name in URL format for nic1
    -nic1externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default for nic1 is 'none'
    -nic1internalip  Only specify this is you want to set an internal IP.  Otherwise the IP for nic1 will be auto assigned.   
 
    What is not supported right now:
    1)  Using different storage classes
    2)  Specifying more than one internal IP per subnet.
    
    If you need either of these, please open an issue in Github.
    

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


    # if recovery point specified without imagename or ID
    if ( (!($imagename)) -and (!($imageid)) -and ($appid) )
    {
        $imagecheck = Get-AGMImage -filtervalue "appid=$appid&jobclass=snapshot&apptype=GCPInstance" -sort id:desc -limit 1
        if ($imagecheck.count -eq 0)
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find any images for appid $appid"
            return
        }
        $imageid = $imagecheck.id
        $imagename = $imagecheck.name
    }



    # learn about the image
    if (($imagename) -and (!($imageid)))
    {
        $imagecheck = Get-AGMImage -filtervalue backupname=$imagename
        if (!($imagecheck))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imagename using:  Get-AGMImage -filtervalue backupname=$imagename"
            return
        }
        else 
        {
            $imagegrab = Get-AGMImage -id $imagecheck.id
            $imageid = $imagegrab.id
        }
    }
    if (($imageid) -and (!($imagename)))
    {
        $imagecheck = Get-AGMImage -id $imageid
        if (!($imagecheck))
        {
            Get-AGMErrorMessage -messagetoprint "Failed to find $imageid using:  Get-AGMImage -id $imageid"
            return
        }
        else 
        {
            $imagename = $imagegrab.name
        }
    }
    if ((!($imagename)) -and (!($imageid)))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify either -imageid or -imagename"
        return
    }

    if (!($credentialid))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a credential ID for the new instance with -credentialid"
        return
    }

    if (!($projectname))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a project for the new instance with -projectname"
        return
    }
    if (!($zone))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a zone for the new instance with -zone"
        return
    }
    if (!($instancename))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a name for the new instance with -instancename"
        return
    }
    if (!($machinetype))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a machinetype for the new instance with -machinetype"
        return
    }

   if (!($nic0network))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a network for nic0 for the new instance with -nic0network"
        return
    }
    if (!($nic0subnet))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a subnet for nic0 for the new instance with -nic0subnet"
        return
    }
    # optionally handle nic1
    if ((!($nic1network)) -and ($nic1subnet))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a network for nic1 for the new instance with -nic1network"
        return
    }
    if ((!($nic1subnet)) -and ($nic1network))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a subnet for nic1 for the new instance with -nic1subnet"
        return
    }

    # cloud credentials
    $json = '{"cloudvmoptions":{"@type":"cloudVmMountRest","fields":[{"displayName":"","name":"cloudcredentials","helpId":1265,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"CLOUD CREDENTIALS NAME","name":"cloudcredential","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"credentialname","name":"' +$credentialid +'","selected":true}],"_getchoices":"getCloudCredentials#cloudcredentiallist,image","_dependent":["project","zone","machinetype","networktag","vpc","subnet","privateips","externalip"],"_default":"1"},'
    #project name
    $json = $json + '{"displayName":"PROJECT NAME","name":"project","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"projectid","name":"' +$projectname +'","selected":true}],"_getchoices":"getAllProjects#handle,cloudcredential","_dependent":["zone","machinetype","networktag","vpc","subnet","privateips","externalip"],"_default":"projectid"},'
    # zone
    $json = $json + '{"displayName":"ZONE","name":"zone","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"zone","name":"' +$zone +'","selected":true}],"_getchoices":"getZones#handle,cloudcredential,region","_dependent":["machinetype","vpc","subnet","privateips","externalip"],"_default":"zone"}],"groupType":"layout"},'
    #instance name
    $json = $json + '{"displayName":"","name":"instancesettings","helpId":1265,"type":"group","description":"","required":true,"modified":true,"children":[{"displayName":"INSTANCE NAME","name":"instancename","helpId":1265,"type":"text","description":"","required":true,"currentValue":"' +$instancename +'","modified":true,"size":40,"_getDefault":"getDefaultInstanceName","invalid":"","_default":"instancename"},'
    # machine type
    $json = $json + '{"displayName":"MACHINE TYPE","name":"machinetype","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"machinetype","name":"' +$machinetype +'","selected":true}],"_getchoices":"getMachineTypes#handle,cloudcredential,region,project,zone","_dependent":["networksettings"],"_default":"machinetype"},'
    # service account
    if ($serviceaccount)
    {
        $json = $json + '{"displayName":"SERVICE ACCOUNT","name":"serviceaccount","helpId":1265,"type":"text","description":"","required":true,"currentValue":"' +$serviceaccount +'","modified":false,"size":40,"_getDefault":"getDefaultServiceAccount","_default":"gserviceaccount.com"},'
    } 
        # network tags   
    if (!($networktags))
    {
        $json = $json + '{"displayName":"NETWORK TAGS","name":"networktag","helpId":1265,"type":"multiselection","description":"","required":false,"modified":false,"minimum":0,"maximum":10,"choices":[{"displayName":"http-server","name":"http-server","selected":false},{"displayName":"https-server","name":"https-server","selected":false}],"_getchoices":"getNetworkTags#handle,cloudcredential,project","_default":"[]"}],"groupType":"layout"},'
    } else {
        $json = $json + '{"displayName":"NETWORK TAGS","name":"networktag","helpId":1265,"type":"multiselection","description":"","required":false,"modified":false,"minimum":0,"maximum":10,"choices":['
        $taggroup = ""
        foreach ($tag in $networktags.Split(","))
        {   
            $taggroup = $taggroup + '{"displayName":"' +$tag +'","name":"' +$tag +'","selected":true},'
        }
        $json = $json + $taggroup.TrimEnd(",")
        $json = $json + '],"_getchoices":"getNetworkTags#handle,cloudcredential,project","_default":"[]"}],"groupType":"layout"},'
    }
    # labels   
    if (!($labels))
    {
        $json = $json + '{"displayName":"","name":"tagsgroup","helpId":1265,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"Labels","name":"tag","helpId":1265,"type":"tagselection","description":"","modified":true,"minimum":1,"maximum":50,"choices":[],"validation":""}],"groupType":"layout"},'
    } else {
        $json = $json + '{"displayName":"","name":"tagsgroup","helpId":1265,"type":"group","description":"","required":true,"modified":true,"children":[{"displayName":"Labels","name":"tag","helpId":1265,"type":"tagselection","description":"","modified":true,"minimum":1,"maximum":50,"choices":['
        $labelgroup = ""
        foreach ($label in $labels.Split(","))
        {   
            $key = $label.Split(":") | Select-object -First 1
            $value = $label.Split(":") | Select-object -skip 1
            $labelgroup = $labelgroup + '{"selected":true,"key":"' +$key +'","value":"' +$value +'"},'
        }
        $json = $json + $labelgroup.TrimEnd(",")
        $json = $json + '],"validation":""}],"groupType":"layout"},'
    }                                                                                                                    
    # network starter
    $json = $json + '{"displayName":"Network Interfaces","name":"networksettings","helpId":1265,"type":"networkinterfaces","description":"","required":true,"modified":false,"minimum":1,"maximum":2,"children":['
    ########## nic0   BEGIN ########
    $json = $json + '{"displayName":"nic0","name":"nic0","helpId":1265,"type":"nic","description":"","required":true,"modified":true,"children":['
    # network
    $json = $json + '{"displayName":"NETWORK","name":"vpc","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic0network +'","selected":true}],"_getchoices":"getVpcs#handle,cloudcredential,region,project,resourcegroup,zone","_dependent":["subnet","privateips"],"_default":"network","parentName":"nic0"},'
    # subnet
    $json = $json + '{"displayName":"SUBNET","name":"subnet","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic0subnet +'","selected":true}],"_getchoices":"getSubnets#handle,cloudcredential,region,vpc,project,zone","_dependent":["privateips"],"_default":"subnet","parentName":"nic0"},'
    # external IP    unless user asks for auto we default to none
    if ($nic0externalip -eq "auto")
    {
        $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0","selected":true},{"displayName":"None","name":"None"}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic0"},'
    } else {
        $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0"},{"displayName":"None","name":"None","selected":true}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic0"},'
    }                                                                                                                    
    # internal IP   The default is auto
    if ($nic0internalip)
    {
        $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic0","modified":false},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic0","modified":true},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":["' +$nic0internalip +'"],"disabled":true,"validation":"","parentName":"nic0"}],"parentName":"nic0"}]}'
    } else {
        $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":false,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic0"},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic0"},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":[],"disabled":true,"validation":"","parentName":"nic0"}],"parentName":"nic0"}]}'
        
    }
    ########## nic0   END ########
    ########## nic1   BEGIN ########
    if (($nic1network) -and ($nic1subnet)) 
    {
        $json = $json + ',{"displayName":"nic1","name":"nic1","helpId":1265,"type":"nic","description":"","required":true,"modified":true,"children":['
        # network
        $json = $json + '{"displayName":"NETWORK","name":"vpc","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic1network +'","selected":true}],"_getchoices":"getVpcs#handle,cloudcredential,region,project,resourcegroup,zone","_dependent":["subnet","privateips"],"_default":"network","parentName":"nic1"},'
        # subnet
        $json = $json + '{"displayName":"SUBNET","name":"subnet","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"default (default)","name":"' +$nic1subnet +'","selected":true}],"_getchoices":"getSubnets#handle,cloudcredential,region,vpc,project,zone","_dependent":["privateips"],"_default":"subnet","parentName":"nic1"},'
        # external IP    unless user asks for auto we default to none
        if ($nic1externalip -eq "auto")
        {
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0","selected":true},{"displayName":"None","name":"None"}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic1"},'
        } else {
            $json = $json + '{"displayName":"EXTERNAL IPV4 IP","name":"externalip","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"choices":[{"displayName":"Auto Assign","name":"0.0.0.0"},{"displayName":"None","name":"None","selected":true}],"_getchoices":"getElasticIPs#handle,project,region,zone,cloudcredential","_default":"None","parentName":"nic1"},'
        }                                                                                                                    
        # internal IP   The default is auto
        if ($nic1internalip)
        {
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic1","modified":false},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic1","modified":true},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":["' +$nic1internalip +'"],"disabled":true,"validation":"","parentName":"nic1"}],"parentName":"nic1"}]}'
        } else {
            $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":false,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic1"},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic1"},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":[],"disabled":true,"validation":"","parentName":"nic1"}],"parentName":"nic1"}]}'
            
        }
    }
    ########## nic1   END ########

    # end networking  
    $json = $json + '],"groupType":"layout"},'
    


    # volumes
    # $json = $json + '{"displayName":"","name":"volumes","helpId":1265,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"Select Volumes to Mount","name":"volumeselection","helpId":1265,"type":"volumeselectiontable","description":"","required":true,"modified":true,"title":"Select Volumes to Mount","header":[{"displayName":"DEVICE NAME","name":"devicename","type":"text"},{"displayName":"SIZE","name":"size","type":"text"},{"displayName":"SOURCE MOUNT PATH","name":"sourcemountpath","type":"text"},{"displayName":"DEVICE INDEX","name":"deviceindex","type":"text"},{"displayName":"VOLUME ID","name":"volumeid","type":"text"},{"displayName":"DEVICE TYPE","name":"devicetype","type":"text"},{"displayName":"DISK TYPE","name":"disktype","type":"selection"}],"rows":[{"size":"10 GB","volumeid":"862641384278357116","devicename":"tiny","disktype":[{"displayName":"Balanced Persistent Disk(DiskSizeGb: 100)","name":"pd-balanced","selected":true}],"sourcemountpath":"dev/sda","devicetype":"BOOT","deviceindex":"0","selected":true,"disabled":true,"disktypeDisabled":false}],"_getchoices":"getVolumeTypes#handle,cloudcredential,region,zone,project,machinetype"}],"groupType":"wizard"},'
    $json = $json + '{"displayName":"","name":"volumes","helpId":1265,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"Select Volumes to Mount","name":"volumeselection","helpId":1265,"type":"volumeselectiontable","description":"","required":false,"modified":false,"title":"Select Volumes to Mount","header":[{"displayName":"DEVICE NAME","name":"devicename","type":"text"},{"displayName":"SIZE","name":"size","type":"text"},{"displayName":"SOURCE MOUNT PATH","name":"sourcemountpath","type":"text"},{"displayName":"DEVICE INDEX","name":"deviceindex","type":"text"},{"displayName":"VOLUME ID","name":"volumeid","type":"text"},{"displayName":"DEVICE TYPE","name":"devicetype","type":"text"},{"displayName":"DISK TYPE","name":"disktype","type":"selection"}],"_getchoices":"getVolumeTypes#handle,cloudcredential,region,zone,project,machinetype"}],"groupType":"wizard"},'
   
    # power on/off VM
    if ($poweronvm -eq "false")
    {
        $json = $json + '{"displayName":"","name":"checkboxgroup","helpId":1265,"type":"group","description":"","modified":false,"children":[{"displayName":"Power On","name":"poweronvm","helpId":1265,"type":"checkbox","description":"","modified":true,"checked":false}],"groupType":"layout"}],'
    } else {
        $json = $json + '{"displayName":"","name":"checkboxgroup","helpId":1265,"type":"group","description":"","modified":false,"children":[{"displayName":"Power On","name":"poweronvm","helpId":1265,"type":"checkbox","description":"","modified":true,"checked":true}],"groupType":"layout"}],'
    }
    # imagename
    $json = $json + '"version":1,"formtype":"newmount","image":"' +$imagename +'","cloudtype":"GCP"}}'
    
    $newgcp = Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json

    if ($newgcp.fields)
    {
        $invalid = (($newgcp.fields | Select-Object children).children | Select-Object invalid).invalid
        Get-AGMErrorMessage -messagetoprint $invalid
    }
    else {
        $newgcp
    }
    
}