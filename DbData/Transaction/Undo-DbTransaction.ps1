<#

#>

function Undo-DbTransaction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName="SqlCommand")]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Data.SqlClient.SqlCommand] $SqlCommand,
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName="DataSet")]
        [ValidateNotNullOrEmpty()]
        [System.Data.DataSet] $DataSet,
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName="DataTable")]
        [ValidateNotNullOrEmpty()]
        [System.Data.DataTable] $DataTable,

        [Alias("SavePointName")]
        [string] $TransactionName
    )

    begin {
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            "SqlCommand" {
                if ($null -eq $SqlCommand.Connection) {
                    Write-Error "SqlCommand must be associated with a SqlConnection before undoing a transaction"
                }
            }
            "DataSet" {
                if ($null -eq $DataSet.Tables[0].SqlDataAdapter.SelectCommand) {
                    Write-Error "DataSet must be associated with a SelectCommand before undoing a transaction"
                }
                $SqlCommand = $DataSet.Tables[0].SqlDataAdapter.SelectCommand
            }
            "DataTable" {
                if ($null -eq $DataTable.SqlDataAdapter.SelectCommand) {
                    Write-Error "DataTable must be associated with a SelectCommand before undoing a transaction"
                }
                $SqlCommand = $InputObject.SqlDataAdapter.SelectCommand
            }
        }

        if ($SqlCommand.Connection.State -ne "Open") {
            Write-Error "SqlCommand must be open before undoing a transaction"
        }
        if ($null -eq $SqlCommand.Transaction) {
            Write-Error "SqlCommand must be associated with a transaction before undoing a transaction"
        }

        if ($TransactionName) {
            $SqlCommand.Transaction.Rollback($TransactionName)
        } else {
            $SqlCommand.Transaction.Rollback()
        }
    }

    end {
    }
}
