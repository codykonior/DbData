<#

.SYNOPSIS
Create an SQL command.

.DESCRIPTION
Creates an SQL command safely. This combines:
* A connection object.
* A command.
* Parameters specified as a hash table.
* Query timeouts.
* An existing transaction.

.PARAMETER Connection
A SqlConnection from New-DbConnection.

.PARAMETER Command
The command or stored procedure name to execute.

.PARAMETER Parameters
A hash table of parameters to use in this query. This is done safely without concatenating strings or using variable substitution.

.PARAMETER QueryTimeout
Integer for the number of seconds to wait before expiring the query. If unspecified the .NET default is 30 seconds.

This normally holds Severity 10 and lower information. If a higher severity error occurs as part of the batch then prior output is included in the Exception instead.

.PARAMETER FireInfoMessageEventOnUserErrors
Messages of severity 10 and lower are output as informational messages, unless an exception occurs, in which case they are bundled in as part of the exception text.

If this parameter is specified, exceptions up to and including severity 16 will be output as messages and not cause processing to stop. On a higher exception, the previous messages will still be printed.

.PARAMETER CommandType
Text, StoredProcedure, or TableDirect.

.PARAMETER Transaction
An existing System.Data.SqlClient.Transaction object.

.PARAMETER VarChar
By default strings are passed as NvarChar parameters (because a .NET [string] is Unicode by default). This can cause some extreme performance issues from implicit conversions (table scans will occur as VarChar columns are converted up to NvarChar). If you know you are reading from VarChar records then this switch allows you to force VarChar type parameters and improve performance.

.INPUTS
Pipe in a connection string, or a System.Data.SqlClient.SqlConnection object.

.OUTPUTS
A System.Data.SqlClient.SqlCommand object.

.EXAMPLE
New-DbConnection .\SQL2016 master | New-DbCommand "Select * From sys.databases Where name = @DatabaseName" @{ DatabaseName = "master" } | Get-DbData

Prepare a connection, a command, and pull back the data.

.EXAMPLE
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance master | New-DbCommand "Raiserror('Hi 1', 10, 1); Raiserror('Hi 2', 10, 1);" | Get-DbData -NonQuery -Verbose
New-DbConnection $serverInstance master | New-DbCommand "Raiserror('Hi 1', 10, 1); Raiserror('Hi 2', 11, 1);" | Get-DbData -NonQuery -Verbose
New-DbConnection $serverInstance master | New-DbCommand "Raiserror('Hi 1', 16, 1); Raiserror('Hi 2', 16, 1);" -FireInfoMessageEventOnUserErrors | Get-DbData -NonQuery -Verbose
New-DbConnection $serverInstance master | New-DbCommand "Raiserror('Hi 1', 16, 1); Raiserror('Hi 2', 17, 1);" -FireInfoMessageEventOnUserErrors | Get-DbData -NonQuery -Verbose

The first query prints some output. The second query doesn't print any output but it is instead bundled into an exception.

The third query prints some output. The fourth query prints output and then triggers an exception.

.NOTES

#>

function New-DbCommand {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Data.SqlClient.SqlConnection] $SqlConnection,

        [Parameter(Mandatory, Position = 0)]
        [Alias("Query")]
        $Command,
        [Parameter(Position = 1)]
        [Hashtable] $Parameters = @{},
        [Parameter(Position = 2)]
        [System.Data.CommandType] $CommandType = "Text",

        [int] $CommandTimeout,
        [switch] $FireInfoMessageEventOnUserErrors,
        [System.Data.SqlClient.SqlTransaction] $Transaction,

        [switch] $VarChar
    )

    begin {
    }

    process {
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($Command, $SqlConnection)
        $sqlCommand.CommandType = $CommandType
        if ($PSBoundParameters.ContainsKey("CommandTimeout")) {
            $sqlCommand.CommandTimeout = $CommandTimeout
        }
        if ($Transaction) {
            $sqlCommand.Transaction = $Transaction
        }
        if ($FireInfoMessageEventOnUserErrors) {
            $sqlCommand.Connection.FireInfoMessageEventOnUserErrors = $FireInfoMessageEventOnUserErrors
        }

        foreach ($parameterName in $Parameters.Keys) {
            # It's not safe to call the shortcut constructor because of boxing issues
            $parameter = New-Object System.Data.SqlClient.SqlParameter
            $parameter.ParameterName = $parameterName
            $parameter.Value = $Parameters[$parameterName]
            if ($null -eq $Parameters[$parameterName]) {
                $parameter.Value = [DBNull]::Value
            }
            if ($VarChar -and $parameter.SqlDbType -eq "NVarChar") {
                $parameter.DbType = "AnsiString"
            }
            [void] $sqlCommand.Parameters.Add($parameter)
        }

        # Return the command
        $sqlCommand
    }

    end {
    }
}
