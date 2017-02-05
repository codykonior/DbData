<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Get-DbWmi {
    [CmdletBinding(DefaultParameterSetName)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ComputerName
    )

    begin {
    }

    process {
        $wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer($ComputerName)

        $wmi
    }

    end {
    }
}
