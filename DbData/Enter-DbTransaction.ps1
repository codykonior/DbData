<#

.SYNOPSIS
Enter a SQL Transaction.

.DESCRIPTION
Enter a SQL Transaction.

.PARAMETER InputObject
A SqlCommand with a SqlConnection, or the output of Get-DbData.

.PARAMETER TransactionName
An optional name for the transaction.

.PARAMETER PassThru
Pass the transaction on in the pipeline for further operations.

.INPUTS
Pipe in the output of New-DbCommand or Get-DbData.

.OUTPUTS
(Optionally) Whatever was piped in.

.EXAMPLE
$serverInstance = ".\SQL2016"
$sql = New-DbConnection $serverInstance master | New-DbCommand "Select @@Trancount" | Enter-DbTransaction "ABC" -PassThru
$sql | Get-DbData -As Scalar
$sql | Exit-DbTransaction -Rollback
$sql | Get-DbData -As Scalar

Results:
1
0

Begin a transaction and show the transaction count increased. Then rollback and show the transaction count decreased.

#>

function Enter-DbTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias("SqlTransaction")]
        [Alias("SqlCommand")]
        $InputObject,
        [Parameter(Position = 0)]
        [string] $TransactionName,
        [System.Data.IsolationLevel] $IsolationLevel,
        [switch] $PassThru
    )

    begin {
    }

    process {
        if ($InputObject -is [System.Data.SqlClient.SqlCommand]) {
            $sqlCommand = $InputObject
        } elseif ($InputObject -is [System.Data.DataTable]) {
            $sqlCommand = $InputObject.SqlDataAdapter.SelectCommand
        } elseif ($InputObject -is [System.Data.DataSet]) {
            $sqlCommand = $InputObject.Tables[0].SqlDataAdapter.SelectCommand
        } else {
            Write-Error "InputObject must be an SqlCommand with an SqlConnection, a DataTable, or a DataSet."
        }

        if (-not $sqlCommand.Connection) {
            Write-Error "InputObject requires a valid associated SqlConnection before a transaction can be started."
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
            $InputObject
        }
    }

    end {
    }
}
