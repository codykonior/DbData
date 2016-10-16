<#

.SYNOPSIS
Enter an SQL Transaction.

.DESCRIPTION
Enter an SQL Transaction.

.PARAMETER SqlObject.
An SqlCommand with an SqlConnection, or the output of Get-DbData.

.PARAMETER TransactionName
An optional name for the transaction.

.INPUTS
Pipe in the output of New-DbCommand or Get-DbData.

.OUTPUTS
The same as was piped in.

.EXAMPLE
Import-Module SqlHelper
$sql = New-DbConnectionString -ServerInstance AG1L -Database master | New-DbCommand "Select @@Trancount" | Enter-DbTransaction "ABC"
$sql.ExecuteScalar()

#>

function Enter-DbTransaction {
    [CmdletBinding(DefaultParameterSetName = "All")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $SqlObject,
        [Parameter(Position = 0)]
        [string] $TransactionName,
        [System.Data.IsolationLevel] $IsolationLevel,
        [switch] $PassThru
    )

    Begin {
    }

    Process {
        if ($SqlObject -is [System.Data.SqlClient.SqlCommand]) {
            $sqlCommand = $SqlObject
        } else {
            if ($SqlObject -is [PSObject] -and $SqlObject.psobject.Properties["DataAdapter"] -and $SqlObject.DataAdapter -is [System.Data.SqlClient.SqlDataAdapter]) {
                $sqlCommand = $SqlObject.DataAdapter.SelectCommand
            } else {
                Write-Error "SqlObject must be an SqlCommand with an SqlConnection, or an SqlDataAdapter with the same."
            }
        }

        if ($sqlCommand.Connection -eq $null) {
            Write-Error "SqlObject requires a valid associated SqlConnection before a transaction can be started."
        }
        
        if ($sqlCommand.Connection.State -ne "Open") {
            Write-Debug "Opening connection"
            $sqlCommand.Connection.Open()
        }

        if ($IsolationLevel) {
            $sqlCommand.Transaction = $sqlCommand.Connection.BeginTransaction($IsolationLevel, $TransactionName)
        } else {
            $sqlCommand.Transaction = $sqlCommand.Connection.BeginTransaction($TransactionName)
        }

        $sqlObject
    }

    End {
    }
}
