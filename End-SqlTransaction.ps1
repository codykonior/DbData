<#

.SYNOPSIS
Ends an SQL Transaction.

.DESCRIPTION
Ends an SQL Transaction with a Commit or Rollback.

.PARAMETER SqlCommand.
An SqlCommand with an SqlConnection and SqlTransaction.

.PARAMETER Commit
Commit the transaction.

.PARAMETER Rollback
Rollback the transaction.

.INPUTS
Pipe in an SqlCommand.

.OUTPUTS
None unless -PassThru is specified.

.EXAMPLE
Import-Module SqlHelper
$sql = New-SqlConnectionString -ServerInstance .\SQL2014 -Database master | New-SqlCommand "Select @@Trancount"
$sql.Connection.Open()
$sql.ExecuteScalar()
$sql | Start-SqlTransaction "ABC"
$sql.ExecuteScalar()
$sql | End-SqlTransaction -Commit
$sql.ExecuteScalar()

#>

function End-SqlTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [Parameter(Mandatory = $true, ParameterSetName = "Commit")]
        [switch] $Commit,
        [Parameter(Mandatory = $true, ParameterSetName = "Rollback")]
        [switch] $Rollback,
        [switch] $PassThru
    )

    Begin {
    }

    Process {
        if ($SqlCommand.Connection -eq $null) {
            Write-Error "SqlCommand requires a valid associated SqlConnection before a transaction can be started."
        } 

        if ($SqlCommand.Transaction -eq $null) {
            Write-Error "SqlCommand needs an active transaction before it can be ended."
        }

        if ($PSCmdlet.ParameterSetName -eq "Commit") {
            $SqlCommand.Transaction.Commit()
        } else {
            $SqlCommand.Transaction.Rollback()
        }

        # Pass on the object
        if ($PassThru) {
            $SqlCommand
        }
    }

    End {
    }
}
