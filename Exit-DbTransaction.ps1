<#

.SYNOPSIS
Exit a SQL transaction.

.DESCRIPTION
Commit or rollback a SQL transaction.

.PARAMETER InputObject
A SqlCommand with a SqlConnection and SqlTransaction. This can be extracted from a DataTable or a DataSet, but not a DataRow.

.PARAMETER Commit
Commit the transaction.

.PARAMETER Rollback
Rollback the transaction.

.PARAMETER PassThru
Pass the transaction on in the pipeline for further operations.

.INPUTS
Pipe in SqlCommand or a DataSet. You cannot pipe in a DataTable because it will be enumerated into DataRows.

.OUTPUTS
(Optionally) Whatever was piped in.

.EXAMPLE
$serverInstance = ".\SQL2016"
$dbData = New-DbConnection $serverInstance | New-DbCommand "Select @@Trancount"
$dbData | Get-DbData -As Scalar
$dbData | Enter-DbTransaction "ABC"
$dbData | Get-DbData -As Scalar
$dbData | Exit-DbTransaction -Commit
$dbData | Get-DbData -As Scalar

Results:
0
1
0

Show the transaction count, begin a transaction and show the transaction count increased. Then rollback and show the transaction count decreased.

#>

function Exit-DbTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias("SqlTransaction")]
        [Alias("SqlCommand")]
        $InputObject,

        [switch] $Commit,
        [switch] $Rollback,

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

        if (!$sqlCommand.Connection) {
            Write-Error "SqlCommand requires a valid associated SqlConnection before a transaction can be started."
        } 

        if (!$SqlCommand.Transaction) {
            Write-Error "SqlCommand needs an active transaction before it can be ended."
        }

        if ($Rollback) {
            $sqlCommand.Transaction.Rollback()
        } else {
            $sqlCommand.Transaction.Commit()
        }

        if ($passThru) {
            $InputObject
        }
    }

    end {
    }
}
