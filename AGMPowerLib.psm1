# Get public function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )

#Dot source the files
    Foreach($import in @($Public.fullname))
   {
       Try
       {
           . $import
       }
       Catch
       {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }