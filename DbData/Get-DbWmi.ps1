<#

.SYNOPSIS
Creates a SQL Server SMO ManagedComputer object for a server.

.DESCRIPTION
Essentially a shortcut for a long object name. These objects can be used to inspect SQL Server related services and their settings.

.PARAMETER ComputerName
A computer name.

.INPUTS
A computer name.

.OUTPUTS
A ManagedComputer object.

.EXAMPLE
$wmi = Get-DbWmi .

#>

function Get-DbWmi {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ComputerName
    )

    begin {
        [void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement")
    }

    process {
        $wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer($ComputerName)
        $wmi
    }

    end {
    }
}
