<#

.SYNOPSIS
Create an SQL Command object.

.DESCRIPTION
Create an SQL Command object. This includes combining a connection or connection string, with a query, parameter sets, timeouts, and transactions.

.PARAMETER Command
The query or stored procedure name to execute.

.PARAMETER Parameters
A hash table of zero or more parameters to use in this query

.PARAMETER Connection
Optional connection string, or SqlConnection object.

.PARAMETER QueryTimeout
Integer for the number of seconds to wait before expiring the query. The .NET default is 30 seconds.

.PARAMETER Message
The name of a globally scoped variable to hold any informational messages returned by SQL Server; for example through Print and Raiserror statements. If it does not exist it will be created if any of these are triggered.

This normally holds Severity 10 and lower information. If a higher severity error occurs as part of the batch then prior output is included in the Exception instead.

.PARAMETER FireInfoMessageEventOnUserErrors
If specified, includes higher Severity information in the Message, up to Severity 16. This means however that no Exception is thrown and the batch will continue to run.

.PARAMETER CommandType
Text, StoredProcedure, or TableDirect.

.PARAMETER Transaction
An existing System.Data.SqlClient.Transaction object.

.INPUTS
Pipe in a connection string, or an System.Data.SqlClient.SqlConnection object.

.OUTPUTS
A System.Data.SqlClient.SqlCommand object.

.EXAMPLE
Preparing a connection and command with some parameters.

Import-Module SqlHelper
$sql = New-DbConnectionString -ServerInstance .\SQL2014 -Database master | New-DbCommand "Select * From sys.databases Where name = @DatabaseName" `@DatabaseName master -QueryTimeout 10

.EXAMPLE
Showing how Message works to populate a variable.

Import-Module SqlHelper -Force
$Error.Clear()
if (Test-Path Variable:Global:Message) {
    Remove-Variable Message
}
$sql = New-DbConnectionString .\SQL2014 -Database master | New-DbCommand "Print 'Hi'" -Message Message
$sql.Connection.Open()
$sql.ExecuteScalar()
$sql.ExecuteScalar()
$VerboseVariable

.EXAMPLE
Demonstrate the various Exception handling.

Import-Module SqlHelper -Force
$sql = New-DbConnectionString .\SQL2014 -Database master | New-DbCommand "Raiserror('Hi', 10, 1)" # No Exception
$sql.Connection.Open()
$sql.ExecuteNonQuery()  
$sql = New-DbConnectionString .\SQL2014 -Database master | New-DbCommand "Raiserror('Hi', 11, 1)" # Exception
$sql.Connection.Open()
$sql.ExecuteNonQuery()  
$sql = New-DbConnectionString .\SQL2014 -Database master | New-DbCommand "Raiserror('Hi', 16, 1)" -FireInfoMessageEventOnUserErrors # No Exception
$sql.Connection.Open()
$sql.ExecuteNonQuery()  
$sql = New-DbConnectionString .\SQL2014 -Database master | New-DbCommand "Raiserror('Hi', 17, 1)" -FireInfoMessageEventOnUserErrors # Exception
$sql.Connection.Open()
$sql.ExecuteNonQuery()  

.NOTES
Verbose output is supported automatically if $VerbosePreference is set at the time of executing the SQL queries, for Severity 1-10 messages.

#>

function New-DbCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Connection, # string or System.Data.SqlClient.SqlConnection

        [Parameter(Mandatory = $true, Position = 0)]
        $Command,
        [Parameter(Position = 1)]
        [Hashtable] $Parameters = @{},
        [Parameter(Position = 2)]
        [System.Data.CommandType] $CommandType = "Text",

        [int] $CommandTimeout,
        [string] $VerboseVariable,
        [switch] $FireInfoMessageEventOnUserErrors,

        [System.Data.SqlClient.SqlTransaction] $Transaction
    )

    Begin {
    }

    Process {
        # If we are passed a connection string instead of a connection, build the connection object
        if (!$Connection) {
            Write-Error "Needs a Connection"
        } elseif ($Connection -is [string]) {
            $Connection = New-Object System.Data.SqlClient.SqlConnection($Connection)
        } 

        # If neither a connection or connection string were specified then no connection is attached
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($Command, $Connection)
        $sqlCommand.CommandType = $CommandType
        if ($CommandTimeout) {
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
            if ($Parameters[$parameterName] -eq $null) {
                $parameter.Value = [DBNull]::Value
            }
            [void] $sqlCommand.Parameters.Add($parameter)
        }

        $script1 = @'
[CmdletBinding()]
param (
    $sender,
    $event
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
'@

        $script2 = @'

if (Test-Path variable:global:VariableName) {
    $VerboseVariableVariable = Get-Variable -Scope "Global" -Name VariableName
} else {
    $VerboseVariableVariable = New-Variable -Scope "Global" -Name VariableName -Value (New-Object Collections.ArrayList) -Passthru
}

$event.Errors | %{
    [void] ($VerboseVariableVariable.Value).Add($_)
}
'@

        $script3 = @'

$event.Errors | %{
    if ($_.Class -le 10) {
        "Msg {0}, Level {1}, State {2}, Line {3}$([Environment]::NewLine){4}" -f $_.Number, $_.Class, $_.State, $_.LineNumber, $_.Message | Write-Verbose
    } else {
        # Should be Write-Error but it doesn't seem to trigger properly (after -FireInfoMessageEventOnUserErrors) and so it would otherwise up getting lost
        "Msg {0}, Level {1}, State {2}, Line {3}$([Environment]::NewLine){4}" -f $_.Number, $_.Class, $_.State, $_.LineNumber, $_.Message | Write-Verbose
    }
}
'@

        if ($VerboseVariable) {
            $VerboseVariableScript = (@($script1, $script2, $script3) -join [Environment]::Newline) -replace "VariableName", $VerboseVariable
        } else {
            $VerboseVariableScript = (@($script1, $script3) -join [Environment]::Newline)
        }
        Write-Debug $VerboseVariableScript

        $Connection.add_InfoMessage([ScriptBlock]::Create($VerboseVariableScript))        

        # Return the command
        $sqlCommand
    }

    End {
    }
}
