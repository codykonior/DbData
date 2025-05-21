<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER ComputerName

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Get-DbManagedComputer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Alias("MachineName")]
        [string] $ComputerName
    )

    begin {

    }

    process {
        $managedComputer = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer($ComputerName)
        $managedComputer
    }

    end {

    }
}
