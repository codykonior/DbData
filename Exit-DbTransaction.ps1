<#

.SYNOPSIS
Exit an SQL Transaction.

.DESCRIPTION
Exit an SQL Transaction with a Commit or Rollback.

.PARAMETER SqlCommand.
An SqlCommand with an SqlConnection and SqlTransaction.

.PARAMETER Commit
Commit the transaction.

.PARAMETER Rollback
Rollback the transaction.

.INPUTS
Pipe in an SqlCommand.

.OUTPUTS
The original SqlCommand.

.EXAMPLE
Import-Module SqlHelper
$sql = New-DbConnectionString -ServerInstance AG1L-Database master | New-DbCommand "Select @@Trancount"
$sql.Connection.Open()
$sql.ExecuteScalar()
$sql | Enter-DbTransaction "ABC"
$sql.ExecuteScalar()
$sql | Exit-DbTransaction -Commit
$sql.ExecuteScalar()

#>

function Exit-DbTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [Parameter(Mandatory = $true, ParameterSetName = "Commit")]
        [switch] $Commit,
        [Parameter(Mandatory = $true, ParameterSetName = "Rollback")]
        [switch] $Rollback
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

        # Return the object
        $SqlCommand
    }

    End {
    }
}
