<#

.SYNOPSIS
Starts an SQL Transaction.

.DESCRIPTION
Starts an SQL Transaction.

.PARAMETER SqlCommand.
An SqlCommand with an SqlConnection.

.PARAMETER TransactionName
An optional name for the transaction.

.INPUTS
Pipe in an SqlCommand.

.OUTPUTS
The same as was piped in.

.EXAMPLE
Import-Module SqlHelper
$sql = New-SqlConnectionString -ServerInstance .\SQL2014 -Database master | New-SqlCommand "Select @@Trancount" | Start-SqlTransaction "ABC" -PassThru
$sql.ExecuteScalar()

#>

function Start-SqlTransaction {
    [CmdletBinding(DefaultParameterSetName = "All")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [Parameter(Position = 0)]
        [string] $TransactionName,
        [System.Data.IsolationLevel] $IsolationLevel,
        [switch] $PassThru
    )

    Begin {
    }

    Process {
        if ($SqlCommand.Connection -eq $null) {
            Write-Error "SqlCommand requires a valid associated SqlConnection before a transaction can be started."
        }
        
        if ($SqlCommand.Connection.State -ne "Open") {
            Write-Verbose "Opening connection"
            $SqlCommand.Connection.Open()
        }

        if ($IsolationLevel) {
            $SqlCommand.Transaction = $SqlCommand.Connection.BeginTransaction($IsolationLevel, $TransactionName)
        } else {
            $SqlCommand.Transaction = $SqlCommand.Connection.BeginTransaction($TransactionName)
        }

        # Pass on the object
        if ($PassThru) {
            $SqlCommand
        }
    }

    End {
    }
}
