<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>
function Get-DbServer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Microsoft.Data.SqlClient.SqlConnection] $SqlConnection,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Microsoft.SqlServer.Management.Common.IRenewableToken] $Token,

        [switch] $Preload
    )

    begin {

    }

    process {
        if ($PSBoundParameters.ContainsKey("Token")) {
            $serverConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($SqlConnection, $Token)
        } else {
            $serverConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($SqlConnection)
        }
        $server = New-Object Microsoft.SqlServer.Management.Smo.Server($serverConnection)

        if ($PSBoundParameters.ContainsKey("Preload") -and $Preload) {
            $server.SetDefaultInitFields($true)
            # Required in all cases due to SMO bugs (untested as of 2025)
            $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.DataFile], $false)
            # Required for managed instances due to SMO bugs (untested as of 2025)
            $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], $false)
            # This is huge so set it to lazy reading only (not supported on SqlAzureDatabase but doesn't throw)
            $server.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.SystemMessage], $false)
        }

        Write-Warning "SMO will keep SqlConnection open. Be sure to close or dispose it after you're done."
        $server
    }

    end {

    }
}
