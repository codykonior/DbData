<#

.SYNOPSIS
Create an SQL Command object.

.DESCRIPTION
Create an SQL Command object. This includes combining a connection or connection string, with a query, parameter sets, timeouts, and transactions.

.PARAMETER Query
The query or stored procedure name to execute.

.PARAMETER Parameters
Zero or more parameters used in the query. These must be specified in the pattern of @VariableName and Value.

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
$sql = New-SqlConnectionString -ServerInstance .\SQL2014 -Database master | New-SqlCommand "Select * From sys.databases Where name = @DatabaseName" `@DatabaseName master -QueryTimeout 10

.EXAMPLE
Showing how Message works to populate a variable.

Import-Module SqlHelper -Force
$Error.Clear()
if (Test-Path Variable:Global:Message) {
    Remove-Variable Message
}
$sql = New-SqlConnectionString .\SQL2014 -Database master | New-SqlCommand "Print 'Hi'" -Message Message
$sql.Connection.Open()
$sql.ExecuteScalar()
$sql.ExecuteScalar()
$Message

.EXAMPLE
Demonstrate the various Exception handling.

Import-Module SqlHelper -Force
$sql = New-SqlConnectionString .\SQL2014 -Database master | New-SqlCommand "Raiserror('Hi', 10, 1)" # No Exception
$sql.Connection.Open()
$sql.ExecuteNonQuery()  
$sql = New-SqlConnectionString .\SQL2014 -Database master | New-SqlCommand "Raiserror('Hi', 11, 1)" # Exception
$sql.Connection.Open()
$sql.ExecuteNonQuery()  
$sql = New-SqlConnectionString .\SQL2014 -Database master | New-SqlCommand "Raiserror('Hi', 16, 1)" -FireInfoMessageEventOnUserErrors # No Exception
$sql.Connection.Open()
$sql.ExecuteNonQuery()  
$sql = New-SqlConnectionString .\SQL2014 -Database master | New-SqlCommand "Raiserror('Hi', 17, 1)" -FireInfoMessageEventOnUserErrors # Exception
$sql.Connection.Open()
$sql.ExecuteNonQuery()  

.NOTES
Verbose output is supported automatically if $VerbosePreference is set at the time of executing the SQL queries, for Severity 1-10 messages.

#>

function New-SqlCommand {
    [CmdletBinding(DefaultParameterSetName = "All")]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $Query,
        [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
        [object[]] $Parameters,

        [Parameter(ValueFromPipeline = $true)]
        $Connection, # string or System.Data.SqlClient.SqlConnection

        [int] $QueryTimeout,
        [string] $Message,
        [System.Data.CommandType] $CommandType = "Text",
        [switch] $FireInfoMessageEventOnUserErrors,

        [Parameter(ParameterSetName = "ExistingTransaction")]
        [System.Data.SqlClient.SqlTransaction] $Transaction
    )

    Begin {
    }

    Process {
        # If we are passed a connection string instead of a connection, build the connection object
        if ($Connection -is [string]) {
            $Connection = New-Object System.Data.SqlClient.SqlConnection($Connection)
        }

        # If neither a connection or connection string were specified then no connection is attached
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($Query, $Connection)
        $sqlCommand.CommandType = $CommandType
        if ($QueryTimeout) {
            $sqlCommand.CommandTimeout = $QueryTimeout
        }
        if ($Transaction) {
            $sqlCommand.Transaction = $Transaction
        }
        if ($FireInfoMessageEventOnUserErrors) {
            $sqlCommand.Connection.FireInfoMessageEventOnUserErrors = $FireInfoMessageEventOnUserErrors
        }

        if ($Parameters) {
            # Check the various error conditions for parameters that are passed in.
            if (($Parameters.Count % 2) -ne 0) {
                Write-Error "Parameters must be passed in pairs in the pattern of @VariableName and Value. A parameter count of $($Parameters.Count) is incorrect."
            } 
            $badParameters = @(0..($Parameters.Count - 1)) | Where { ($_ % 2) -eq 0 } | Where { $Parameters[$_] -isnot [string] -or $Parameters[$_] -notlike "@*" } | %{ $_ + 1 }
            if ($badParameters) {
                Write-Error "Parameters must be passed in pairs in the pattern of @VariableName and Value. Parameters at these indexes are incorrect: $($badParameters)."            
            }

            # Build the parameter set
            $parameterIndex = 0
            while (($parameterIndex + 1) -lt $Parameters.Count) {
                $parameter = New-Object System.Data.SqlClient.SqlParameter($Parameters[$parameterIndex++], $Parameters[$parameterIndex++])
                [void] $sqlCommand.Parameters.Add($parameter)
            }
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
    $messageVariable = Get-Variable -Scope "Global" -Name VariableName
} else {
    $messageVariable = New-Variable -Scope "Global" -Name VariableName -Value @() -Passthru
}

$event.Errors | %{
    try {
        $messageVariable.Value += $_
    } catch {
        $_
    }
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

        if ($Message) {
            $messageScript = (@($script1, $script2, $script3) -join [Environment]::Newline) -replace "VariableName", $Message
        } else {
            $messageScript = (@($script1, $script3) -join [Environment]::Newline)
        }
        Write-Debug $messageScript

        $Connection.add_InfoMessage([ScriptBlock]::Create($messageScript))        

        # Return the command
        $sqlCommand
    }

    End {
    }
}
