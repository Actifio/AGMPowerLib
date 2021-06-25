Function New-AGMLibMultiMount ([array]$imagelist,[array]$hostlist,[switch][alias("c")]$condatesuffix,[switch][alias("i")]$imagesuffix,[string]$label,[int]$startindex) 
{
    <#
    .SYNOPSIS
    Mounts a number of FileSystems to a group of hosts

    .EXAMPLE
    New-AGMLibMultiMount -imagelist $imagelist -hostlist $hostlist -prefix "recover-"

    This command likes to use the output of Get-AGMLibImageRange as $imagelist
    So we could create a list like this:
    $imagelist = Get-AGMLibImageRange -fuzzyappname demo-sql -olderlimit 3

    We could get a list of hosts to mount to with a command like this:
    $hostlist = Get-AGMHost -filtervalue "hostname~scanhost*" | select id,hostname

    The prefix is optional but recommended
    The suffix is optional but recommended

    There are three mechanisms to get unique mount names:
    1)  You can specify -i and the Image Name will be used as the mount point
    2)  You can instead specify -c and the Consistency Date will be appended as a suffix to the mountpoint
    3)  If you don't specify -c or -i, then if more than one image from a single application is in the image list, then an incremental numerical suffix will be applied.
    If you want to control the starting number of that index use -startindex

    By default it will use a label of "MultiFS Recovery" to make the mounts easier to find 

    .EXAMPLE
    New-AGMLibMultiMount -imagelist $imagelist -hostid $hostid  -prefix "recover-"
    
    If you only have a single  host you can specify it singly using -hostid
    All your mounts will go to that single Host 

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

    # handle esxlist
    if ($hostlist.id)
    {
        $hostlist = ($hostlist).id 
    }
    if ( (!($hostlist)) -and ($hostid) )
    {
        $hostlist = $hostid
    }


    if (!($imagelist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an imagelist"
        return
    }
    
    if (!($hostlist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an array of Host IDs using -hostlist or a single  Host ID using -hostid"
        return
    }

    if (!($startindex))
    {
        $startindex = 1
    }
    

    if (!($label))
    {
        $label = "MultiFS Recovery"
    }

    $hostcount = $hostlist.count
    $hostoundrobin = 0
    $lastappid = ""
    $lastcondate = ""

    foreach ($image in $imagelist)
    {
        if (($lastappid -eq $image.appid) -and ($lastcondate -eq $image.consistencydate))
        {
            Write-Host "Not mounting AppName:" $image.appname " Jobclass:" $image.jobclass " ImageName:" $image.backupname " ConsistencyDate:" $image.consistencydate "because the previous mount had the same appid and consistency date" 
        }
        else 
        {
            $mountpointperimage=$image.appname + $startindex
            # we can now set the values needed for the mount
            $imageid = $image.id
            $hostid = $hostlist[$hostoundrobin]
            $body = [ordered]@{
                label = "$label";
                image = $image.backupname;
                host = @{id=$targethostid}
                migratevm = "false";
                $restoreoptions = @(
                @{
                    name = 'mountpointperimage'
                    value = "$mountpointperimage"
                }
                )
            }
            $json = $body | ConvertTo-Json
            Write-Host "    Mounting AppName:" $image.appname " Jobclass:" $image.jobclass " ImageName:" $image.backupname " ConsistencyDate:" $image.consistencydate "to Host ID" $hostid "with mount point" $mountpointperimage
            Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json
            $hostroundrobin += 1
            $startindex +=1
            if ($hostroundrobin -eq $hostcount )
            {
                $hostroundrobin = 0
            }
            $lastappid = $image.appid
            $lastcondate = $image.consistencydate
        }
    }
}