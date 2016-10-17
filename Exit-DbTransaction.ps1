<#

.SYNOPSIS
Exit a SQL transaction.

.DESCRIPTION
Commit or rollback a SQL transaction.

.PARAMETER SqlObject
A SqlCommand with a SqlConnection and SqlTransaction. This can be extracted
from a DataTable or a DataSet, but not a DataRow.

If the DataSet has multiple tables only the first one is used.

.PARAMETER Commit
Commit the transaction.

.PARAMETER Rollback
Rollback the transaction.

.INPUTS
Pipe in SqlCommand or a DataSet. You cannot pipe in a DataTable because it
will be enumerated into DataRows.

.OUTPUTS
(Optional) Input.

.EXAMPLE
Show a transaction being created and destroyed.

Import-Module DbData
$serverInstance = "AG1L"
$dbData = New-DbConnection $serverInstance | New-DbCommand "Select @@Trancount"
$dbData.Connection.Open()
$dbData.ExecuteScalar()
$dbData | Enter-DbTransaction "ABC"
$dbData.ExecuteScalar()
$dbData | Exit-DbTransaction -Commit
$dbData.ExecuteScalar()

#>

function Exit-DbTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $SqlObject,

        [switch] $Commit,
        [switch] $Rollback,

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
            $SqlObject
        }
    }

    end {
    }
}
