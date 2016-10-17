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
(Optionally) Whatever was piped in.

.EXAMPLE
Begin a transaction and show the transaction count increased. Then rollback and show the transaction count decreased.

Import-Module DbData
$serverInstance = "AG1L"
$sql = New-DbConnection $serverInstance | New-DbCommand "Select @@Trancount" | Enter-DbTransaction "ABC" -PassThru
$sql.ExecuteScalar()
$sql | Exit-DbTransaction -Rollback
$sql.ExecuteScalar()

#>

function Enter-DbTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $SqlObject,
        [Parameter(Position = 0)]
        [string] $TransactionName,
        [System.Data.IsolationLevel] $IsolationLevel,
        [switch] $PassThru
    )

    begin {
    }

    process {
        if ($SqlObject -is [System.Data.SqlClient.SqlCommand]) {
            $sqlCommand = $SqlObject
        } elseif ($SqlObject -is [System.Data.DataTable]) {
            $sqlCommand = $SqlObject.SqlDataAdapter.SelectCommand
        } elseif ($SqlObject -is [System.Data.DataSet]) {
            $sqlCommand = $SqlObject.Tables[0].SqlDataAdapter.SelectCommand
        } else {
            Write-Error "SqlObject must be an SqlCommand with an SqlConnection, a DataTable, or a DataSet."
        }

        if (!$sqlCommand.Connection) {
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

        if ($PassThru) {
            $SqlObject
        }
    }

    end {
    }
}
