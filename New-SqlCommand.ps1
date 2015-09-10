<#

.SYNOPSIS
Create an SQL Command object.

.DESCRIPTION
Create an SQL Command object. This includes combining a connection or connection string, with a query, parameter sets, timeouts, and transactions.


.INPUTS
Pipe in a connection string, or an System.Data.SqlClient.SqlConnection object.

.OUTPUTS
A System.Data.SqlClient.SqlCommand object.

.EXAMPLE
$sqlCommand = New-SqlConnectionString -ServerInstance .\SQL2014 -Database master | New-SqlCommand "Select * From sys.databases Where name = @DatabaseName" `@DatabaseName master -CommandTimeout 10

#>

function New-SqlCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $Query,
        [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
        [object[]] $Parameters,

        [Parameter(ValueFromPipeline = $true)]
        $Connection, # string or System.Data.SqlClient.SqlConnection

        [int] $CommandTimeout,
        [string] $InfoMessageVariable,
        [System.Data.CommandType] $CommandType = "Text",
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
        if ($CommandTimeout) {
            $sqlCommand.CommandTimeout = $CommandTimeout
        }
        if ($Transaction) {
            $sqlCommand.Transaction = $Transaction
        }
 
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

        # Optionally we attach a script which will write info messages to a variable    
        if ($InfoMessageVariable) {
            $infoMessageScriptBlock = @"
Param (`$sender, `$event)
Set-StrictMode -Version Latest

`$infoMessageVariable = [ref] @() # Populate an empty array, to discard later, if we found no proper variable
if (Test-Path variable:global:$InfoMessageVariable) {
    `$infoMessageVariable = Get-Variable -Scope "Global" -Name $InfoMessageVariable -ErrorAction:Stop
}

`$event.Errors | %{
    `$infoMessageVariable.Value += `$_
    "Msg {0}, Level {1}, State {2}, Line {3}`n{4}" -f `$_.Number, `$_.Class, `$_.State, `$_.LineNumber, `$_.Message | Write-Debug
}
"@
            $sqlConnection.add_InfoMessage([ScriptBlock]::Create($infoMessageScriptBlock))        
        }
  
        # Return the command
        $sqlCommand
    }

    End {
    }
}
