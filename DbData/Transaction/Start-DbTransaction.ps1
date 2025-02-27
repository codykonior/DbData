<#

#>

function Start-DbTransaction {
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

        [string] $TransactionName,
        [System.Data.IsolationLevel] $IsolationLevel,
        [switch] $PassThru
    )

    begin {
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            "SqlCommand" {
                if ($null -eq $SqlCommand.Connection) {
                    Write-Error "SqlCommand must be associated with a SqlConnection before starting a transaction"
                }
            }
            "DataSet" {
                if ($null -eq $DataSet.Tables[0].SqlDataAdapter.SelectCommand) {
                    Write-Error "DataSet must be associated with a SelectCommand before starting a transaction"
                }
                $SqlCommand = $DataSet.Tables[0].SqlDataAdapter.SelectCommand
            }
            "DataTable" {
                if ($null -eq $DataTable.SqlDataAdapter.SelectCommand) {
                    Write-Error "DataTable must be associated with a SelectCommand before starting a transaction"
                }
                $SqlCommand = $InputObject.SqlDataAdapter.SelectCommand
            }
        }

        if ($SqlCommand.Connection.State -ne "Open") {
            $SqlCommand.Connection.Open()
        }

        if ($IsolationLevel) {
            $SqlCommand.Transaction = $SqlCommand.Connection.BeginTransaction($IsolationLevel, $TransactionName)
        } else {
            $SqlCommand.Transaction = $SqlCommand.Connection.BeginTransaction($TransactionName)
        }

        if ($PassThru) {
            $PSItem
        }
    }

    end {
    }
}
