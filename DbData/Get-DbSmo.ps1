<#

.SYNOPSIS
Creates an SQL Server SMO Server object for a database engine instance.

.DESCRIPTION
While it's easy to instantiate a connection to SQL Server SMO it has a few bugs that require extra workarounds.

* It doesn't provide a simple interface to set a timeout.
* It has a bug which prevent DefaultInitFields from being set to retrieve and cache all fields (without a specific exception it will cause failures on some database properties).
* It can return an object even if the server is not up.
* And even then the object can silently swallow errors and return blank fields if the server is not up.

This wrapper gets around each of these faults, the last of which by connecting and disconnecting, which keeps a connection alive in the pool, but closed so it doesn't require further management. Testing shows that this is sufficient to cause the object to flag errors on dead servers.

.PARAMETER ServerInstance
A server instance to connect to, for example ".\SQL2016"

.PARAMETER SqlCredential
A SqlCredential containing the username and password for use with a ServerInstance.

.PARAMETER SqlConnection
A SqlConnection object.

.PARAMETER Preload
Cache all possible data in a minimum of reads.

.PARAMETER PreloadAg
Only cache Availability Group data (otherwise this is extremely chatty).

.PARAMETER Raw
If you pass in a SqlConnection object by default it is used to construct a new one, this is required for SMO to automatically
manage soft-closing the connection (as it sets a NonPooled property which cannot be modified). If you don't care about this
behaviour this switch allows the use of the raw connection, just remember SMO won't close it.

.INPUTS
A server name or a connection object.

.OUTPUTS
An SMO Server object.

.EXAMPLE
$smo = Get-DbSmo . -Preload

#>

function Get-DbSmo {
    [CmdletBinding(DefaultParameterSetName = "ServerInstance")]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = "SqlConnection", Position = 1)]
        [Microsoft.Data.SqlClient.SqlConnection] $SqlConnection,

        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = "ServerInstance", Position = 1)]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = "SqlConnection", Position = 2)]
        [Alias("ServerName")]
        [Alias("SqlServerName")]
        [Alias("DataSource")]
        [string] $ServerInstance,

        [Alias("SqlCredential")]
        $Credential,

        [Parameter(ParameterSetName = "SqlConnection")]
        [switch] $Raw,

        [switch] $Preload,
        [switch] $PreloadAg,

        $RetryCount,
        $RetrySeconds,

        [switch] $OverrideOpen
    )

    begin {
    }

    process {
        if ($Raw -and $PSCmdlet.ParameterSetName -eq "SqlConnection") {
            $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($SqlConnection)
        } elseif ($Credential) {
            $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($ServerInstance, $Credential.UserId, $Credential.Password)
        } else {
            $connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($ServerInstance)
        }
        if ($OverrideOpen) {
            # It instantiates its own connection but we'll still add our own Open logic to keep it enterprise-ready ;-)
            Add-DbOpen $connection.SqlConnectionObject
        }

        # Server can be initialised with either a server name or a serverconnection object
        $smo = New-Object Microsoft.SqlServer.Management.Smo.Server($connection)

        Use-DbRetry {
            if ($Preload) {
                $smo.SetDefaultInitFields($true)
                # Required in all cases due to SMO bugs
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.DataFile], $false)
                # Required for managed instances due to SMO bugs
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.Database], $false)
                # This is huge so set it to lazy reading only
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.SystemMessage], $false)
            } elseif ($PreloadAg) {
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.AvailabilityGroup], $true)
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.AvailabilityReplica], $true)
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.DatabaseReplicaState], $true)
            }

            $smo.ConnectionContext.Connect() # Get ready
            if (-not $smo.Version) {
                Write-Error -Exception (New-Object System.Data.DataException("SMO connection silently failed"))
            }
            $smo.ConnectionContext.Disconnect() # Keeps it in the pool, let SMO manage it (maybe)
            $smo
        } -RetryCount $RetryCount -RetrySeconds $RetrySeconds
    }

    end {
    }
}
