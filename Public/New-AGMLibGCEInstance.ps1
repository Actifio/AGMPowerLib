Function New-AGMLibGCEInstance ([string]$imageid,[string]$imagename,[string]$credentialid,[string]$credentialname,[string]$projectname,[string]$zone,[string]$instancename,[string]$machinetype,[string]$serviceaccount,[string]$nic0network,[string]$nic0subnet,[string]$nic0externalip,[string]$nic0internalip,[string]$poweronvm) 
{
    <#
    .SYNOPSIS
    Mounts a PD Snapshot as a new GCE Instance
    To learn which Applications are suitable:
    Get-AGMApplication -filtervalue "apptype=GCPInstance&managed=True" 

    To learn which Cloud Credentials are available.   The credentialid is the srcid.
    Get-AGMCredential

    .EXAMPLE
    New-AGMLibGCEInstance -imageid 56410933 -credentialid 1234 -credentialname cred1 -zone australia-southeast1-c -projectname myproject -instancename avtest21 -machinetype e2-micro -serviceaccount serviceaccount@google.com -networktags "http-server,https-server" -labels "dog;cat,sheep;cow" -nic0network "https://www.googleapis.com/compute/v1/projects/projectname/global/networks/default" -nic0subnet "https://www.googleapis.com/compute/v1/projects/projectname/regions/australia-southeast1/subnetworks/default" -nic0externalip auto -nic0internalip "10.152.0.200" -poweronvm false

    This mounts the specified imageid

    To learn the first three parameters below, you could use this command:

    Get-AGMImage -filtervalue "apptype=GCPInstance&jobclass=snapshot" | select appname,id,name,consistencydate,diskpool | ft
    
    There are many paramters that need to be supplied:

    -imageid         You need to supply either the imageid or the imagename or both
    -imagename       You need to supply either the imageid or the imagename or both
    -credentialid    Learn this with Get-AGMCredential.  The credentialid is the srcid.
    -credentialname  Learn this with Get-AGMCredential.  The credentialname is the name.
    -projectname     This is the unique Google Project name
    -zone            This is the GCP Zone such as: australia-southeast1-c
    -instancename    This is the name of the new instance that will be created.   It needs to be unique in that project
    -machinetype     This is the GCP instance machine type such as:  e2-micro
    -serviceaccount  The service account that is being used to request the instance creation
    -networktags     Comma separate as many tags as you have, for instance:   -networktags "http-server,https-server"   
    -labels          Labels are key value pairs.   Separate key and value with semi colons and each label with commas.   For example:   -labels "dog;cat,sheep;cow"
    -nic0network     The network name in URL format
    -nic0subnet      The subnet name in URL format
    -nic0externalip  Only 'none' and 'auto' are valid choices.  If you don't use this variable then the default is 'none'
    -nic0internalip  Only specify this is you want to set an internal IP.  Otherwise the IP will be auto assigned.   
    -poweronvm       By default the new GCE Instance will be powered on.   If you want it to be created but left powered off, then specify: -poweronvm false
                     There is no need to specify: -poweronvm true 


    .DESCRIPTION
    A function to create a new GCE Instance from a PD Snapshot


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
            $imagename = $imagegrab.backupname
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
    if (!($credentialname))
    {
        Get-AGMErrorMessage -messagetoprint "Please specify a credential name for the new instance with -credentialname"
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
    if (!($nic0externalip))
    {

    }
    if (!($nic0internalip))
    {

    }


    # cloud credentials
    $json = '{"cloudvmoptions":{"@type":"cloudVmMountRest","fields":[{"displayName":"","name":"cloudcredentials","helpId":1265,"type":"group","description":"","required":true,"modified":false,"children":[{"displayName":"CLOUD CREDENTIALS NAME","name":"cloudcredential","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"' +$credentialname  +'","name":"' +$credentialid +'","selected":true}],"_getchoices":"getCloudCredentials#cloudcredentiallist,image","_dependent":["project","zone","machinetype","networktag","vpc","subnet","privateips","externalip"],"_default":"1"},'
    #project name
    $json = $json + '{"displayName":"PROJECT NAME","name":"project","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"projectid","name":"' +$projectname +'","selected":true}],"_getchoices":"getAllProjects#handle,cloudcredential","_dependent":["zone","machinetype","networktag","vpc","subnet","privateips","externalip"],"_default":"projectid"},'
    # zone
    $json = $json + '{"displayName":"ZONE","name":"zone","helpId":1265,"type":"selection","description":"","required":true,"modified":true,"dynamic":true,"choices":[{"displayName":"zone","name":"' +$zone +'","selected":true}],"_getchoices":"getZones#handle,cloudcredential,region","_dependent":["machinetype","vpc","subnet","privateips","externalip"],"_default":"zone"}],"groupType":"layout"},'
    #instance name
    $json = $json + '{"displayName":"","name":"instancesettings","helpId":1265,"type":"group","description":"","required":true,"modified":true,"children":[{"displayName":"INSTANCE NAME","name":"instancename","helpId":1265,"type":"text","description":"","required":true,"currentValue":"' +$instancename +'","modified":true,"size":40,"_getDefault":"getDefaultInstanceName","invalid":"","_default":"instancename"},'
    # machine type
    $json = $json + '{"displayName":"MACHINE TYPE","name":"machinetype","helpId":1265,"type":"selection","description":"","required":true,"modified":false,"dynamic":true,"choices":[{"displayName":"machinetype","name":"' +$machinetype +'","selected":true}],"_getchoices":"getMachineTypes#handle,cloudcredential,region,project,zone","_dependent":["networksettings"],"_default":"machinetype"},'
    # service account
    $json = $json + '{"displayName":"SERVICE ACCOUNT","name":"serviceaccount","helpId":1265,"type":"text","description":"","required":true,"currentValue":"' +$serviceaccount +'","modified":false,"size":40,"_getDefault":"getDefaultServiceAccount","_default":"gserviceaccount.com"},'
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
            $key = $label.Split(";") | Select-object -First 1
            $value = $label.Split(";") | Select-object -skip 1
            $labelgroup = $labelgroup + '{"selected":true,"key":"' +$key +'","value":"' +$value +'"},'
        }
        $json = $json + $labelgroup.TrimEnd(",")
        $json = $json + '],"validation":""}],"groupType":"layout"},'
    }                                                                                                                    
    # nic0
    $json = $json + '{"displayName":"Network Interfaces","name":"networksettings","helpId":1265,"type":"networkinterfaces","description":"","required":true,"modified":false,"minimum":1,"maximum":2,"children":[{"displayName":"nic0","name":"nic0","helpId":1265,"type":"nic","description":"","required":true,"modified":true,"children":['
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
        $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":true,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic0","modified":false},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic0","modified":true},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":["' +$nic0internalip +'"],"disabled":true,"validation":"","parentName":"nic0"}],"parentName":"nic0"}]}],"groupType":"layout"},'
    } else {
        $json = $json + '{"displayName":"INTERNAL IPV4 IP","name":"internalip","helpId":1265,"type":"internalipaddress","description":"","modified":false,"children":[{"displayName":"Auto Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":true,"parentName":"nic0"},{"displayName":"Manual Assign","name":"internalipassign","helpId":1265,"type":"radiobutton","checked":false,"parentName":"nic0"},{"name":"privateips","helpId":1265,"type":"ipaddress","modified":true,"minimum":1,"maximum":2,"_getchoices":"getCIDRBlock#handle,cloudcredential,zone,project,vpc,subnet","values":[],"disabled":true,"validation":"","parentName":"nic0"}],"parentName":"nic0"}]}],"groupType":"layout"},'
    }
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
    
    Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json
    
    
}