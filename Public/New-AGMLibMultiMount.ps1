Function New-AGMLibMultiMount ([array]$imagelist,[array]$hostlist,[string]$mountpoint,[switch][alias("a")]$appnamesuffix, [switch][alias("h")]$hostnamesuffix,[switch][alias("c")]$condatesuffix,[switch][alias("i")]$imagesuffix,[string]$label,[int]$startindex) 
{
    <#
    .SYNOPSIS
    Mounts a number of FileSystems to a group of hosts

    .EXAMPLE
    New-AGMLibMultiMount -imagelist $imagelist -hostlist $hostlist -mountpoint /tmp/imagecheck

    This command likes to use the output of Get-AGMLibImageRange as $imagelist
    So we could create a list like this:
    $imagelist = Get-AGMLibImageRange -fuzzyappname demo-sql -olderlimit 3

    We could get a list of hosts to mount to with a command like this:
    $hostlist = Get-AGMHost -filtervalue "hostname~scanhost*" | select id,hostname

    The logic to handle mount points is simple.
    The user must supply a starter mount point with a trailing slash.
    For linux hosts this would be:    -mountpoint /tmp/testmount/
    For Windows hosts this would be:  -mountpoint C:\temp\

    The suffix is optional but recommended.  This basically adds an extra foldername to the mount point.

    There are four mechanisms to get unique mount names:
    1)  You can specify -h and the Host Name will be used as part of the mount point
    2)  You can specify -a and the App Name will be used as part of the mount point
    3)  You can specify -i and the Image Name will be used as part of the mount point
    4)  You can specify -c and the Consistency Date will be used as part of the mountpoint
   
    The point point will always end in a unique number to guarantee uniqueness.
    If you want to control the starting number of that number use -startindex

    By default it will use a label of "MultiFS Recovery" to make the mounts easier to find.  you can changes this with -label xxxx  to set your own unique label.

    .EXAMPLE
    New-AGMLibMultiMount -imagelist $imagelist -hostid $hostid  -mountpoint "/tmp/testmount/"
    
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

    # handle hostlist vs hostid
    if ($hostlist.id)
    {
        $hostlist = ($hostlist).id 
    }
    if ( (!($hostlist)) -and ($hostid) )
    {
        $hostlist = $hostid
    }

    if (!($mountpoint))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply a starter mountpoint such as /tmp/testmount/ or C:\Temp\"
        return
    }

    if ($mountpoint -match '\\$')
    { $fieldsep = "\" }
    if ($mountpoint -match '/$')
    { $fieldsep = "/" }
    
    if (!($fieldsep))
    {
        Get-AGMErrorMessage -messagetoprint "Last character of $mountpoint needs to be forward slash for Linux such as /tmp/testmount/ or backslash for Windows such C:\Temp\"
        return
    }



    if (!($imagelist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an imagelist"
        return
    }
    
    if (!($hostlist))
    {
        Get-AGMErrorMessage -messagetoprint "Please supply an array of Host IDs using -hostlist or a single Host ID using -hostid"
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
    $hostroundrobin = 0
    $lastappid = ""
    $lastcondate = ""

    # The user can specify the starting number or we will start at 1
    if (!($startindex))
    {
        $startindex = 1
    }
    

    foreach ($image in $imagelist)
    {
        # start the moint point
        $imagemountpoint = $mountpoint
        if (($lastappid -eq $image.appid) -and ($lastcondate -eq $image.consistencydate))
        {
            Write-Host "Not mounting AppName:" $image.appname "AppID:" $image.appid " Jobclass:" $image.jobclass " ImageName:" $image.backupname " ConsistencyDate:" $image.consistencydate "because the previous mount had the same appid and consistency date" 
        }
        else 
        {
            if ($hostnamesuffix)
            { 
                # for linux mount points starting with / we need to trim the leading / to avoid // in the mount point
                if ($image.hostname.Substring(0,1) -match "[/]")
                {
                    $image.hostname = $image.hostname.substring(1) 
                }
                # we also remove spaces in app names and full colon, so they dont make strange mount points
                $imagemountpoint = $imagemountpoint + $image.hostname -replace '\s','' -replace ':',''  
                $imagemountpoint = $imagemountpoint + $fieldsep
            }
            if ($appnamesuffix)
            { 
                # for linux mount points starting with / we need to trim the leading / to avoid // in the mount point
                if ($image.appname.Substring(0,1) -match "[/]")
                {
                    $image.appname = $image.appname.substring(1) 
                }
                # we also remove spaces in app names and full colon, so they dont make strange mount points
                $imagemountpoint = $imagemountpoint + $image.appname -replace '\s','' -replace ':',''  
                $imagemountpoint = $imagemountpoint + $fieldsep
            }
            if ($imagesuffix)
            { $imagemountpoint = $imagemountpoint + $image.backupname + $fieldsep }
            if ($condatesuffix)
            {  
                # we need to make the date just numbers
                $imagemountpoint = $imagemountpoint + $image.consistencydate -replace '\s','' -replace '-','' -replace ':',''  
                $imagemountpoint = $imagemountpoint + $fieldsep
            }

            # we always end on a number to guarantee uniqueness
            $imagemountpoint = $imagemountpoint + $startindex 
            $startindex += 1

            # we can now set the values needed for the mount
            $hostid = $hostlist[$hostroundrobin]
            $body = [ordered]@{
                label = "$label";
                image = $image.backupname;
                host = @{id=$hostid}
                migratevm = "false";
                restoreoptions = @(
                    @{
                        name = 'mountpointperimage'
                        value = "$imagemountpoint"
                    }
                )
            }
            $json = $body | ConvertTo-Json -depth 4
            Write-Host "    Mounting AppName:" $image.appname " AppID:" $image.appid " Jobclass:" $image.jobclass " ImageName:" $image.backupname " ConsistencyDate:" $image.consistencydate "to Host ID" $hostid "with mount point" $imagemountpoint           
            $imageid = $image.id
            Post-AGMAPIData  -endpoint /backup/$imageid/mount -body $json
            $hostroundrobin += 1
            if ($hostroundrobin -eq $hostcount )
            {
                $hostroundrobin = 0
            }
            $lastappid = $image.appid
            $lastcondate = $image.consistencydate
        }
    }
}