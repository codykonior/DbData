<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Get-DbSmo {
    [CmdletBinding(DefaultParameterSetName)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ServerInstance,
        [switch] $Preload,
        [switch] $PreloadAg
    )

    begin {
    }

    process {
        Use-DbRetry {
            $connection = New-Object Microsoft.SqlServer.Management.Common.SqlConnectionInfo($ServerInstance)
            $connection.ConnectionTimeout = 60
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
            $smo.ConnectionContext.Disconnect() # Keeps it in the pool, let SMO manage it
            $smo
        }
    }

    end {
    }
}
