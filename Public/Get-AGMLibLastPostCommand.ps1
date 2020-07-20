Function Get-AGMLibLastPostCommand([string]$username,[int]$limit) 
{
    <#
    .SYNOPSIS
    Gets the last POST command issued by a nominated user

    .EXAMPLE
    Get-AGMLibLastPostCommand
    You will be prompted for a JobName

    .EXAMPLE
    Get-AGMLibLastPostCommand av
    Get the last post command issued by the user called av

        .EXAMPLE
    Get-AGMLibLastPostCommand av 2
    Get the last two post commands issued by the user called av

    .DESCRIPTION
    A function to get the audit log for the last command you ran

    #>


    if ( (!($AGMSESSIONID)) -or (!($AGMIP)) )
    {
        Get-AGMErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-AGM"
        return
    }

    if (!($username))
    {
        $username = Read-Host "UserName"
    }

    if (!($limit))
    {
        $limit = 1
    }
    Get-AGMAudit -filtervalue "username=$username&command~POST http" -limit $limit -sort id:desc 
}