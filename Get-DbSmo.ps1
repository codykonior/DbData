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

.PARAMETER Preload
Cache all possible data in a minimum of reads.

.PARAMETER PreloadAg
Only cache Availability Group data (otherwise this is extremely chatty).
 
.INPUTS
A server instance name.

.OUTPUTS
An SMO Server object.

.EXAMPLE
$smo = Get-DbSmo ".\SQL2016" -Preload

#>

function Get-DbSmo {
    [CmdletBinding(DefaultParameterSetName = "ServerInstance")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "ServerInstance", Position = 0)]
		$ServerInstance,
        [Parameter(ParameterSetName = "ConnectionString")]
        $ConnectionString,

        [switch] $Preload,
        [switch] $PreloadAg
    )

    begin {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
    }

    process {
		Use-DbRetry {
			$connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
	        $connection.ConnectTimeout = 60

			if ($PSCmdlet.ParameterSetName -eq "ConnectionString") {
				$connection.ConnectionString = $ConnectionString
			} else {
				$connection.ServerInstance = $ServerInstance
			}
			Add-DbOpen $connection.SqlConnectionObject

			$smo = New-Object Microsoft.SqlServer.Management.Smo.Server($connection)

            if ($Preload) {
                $smo.SetDefaultInitFields($true)
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.DataFile], $false)   
            } elseif ($PreloadAg) {
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.AvailabilityGroup], $true)
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.AvailabilityReplica], $true)
                $smo.SetDefaultInitFields([Microsoft.SqlServer.Management.Smo.DatabaseReplicaState], $true)
            }

            $smo.ConnectionContext.Connect() # Get ready
			if (!$smo.ComputerNamePhysicalNetBIOS) {
				throw (New-Object System.Data.DataException("SMO connection silently failed"))
			}
            $smo.ConnectionContext.Disconnect() # Keeps it in the pool, let SMO manage it
            $smo
		}
    }

    end {
    }
}
