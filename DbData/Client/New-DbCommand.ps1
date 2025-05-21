<#

.SYNOPSIS
Represents a Transact-SQL statement or stored procedure to execute against a SQL Server database.

.DESCRIPTION

.PARAMETER Connection
The SqlConnection used by this instance of the SqlCommand.

.PARAMETER RetryLogicProvider
Specifies the SqlRetryLogicBaseProvider object bound to this command.

.PARAMETER Notification
Specifies the SqlNotificationRequest object bound to this command.

.PARAMETER Transaction
The SqlTransaction within which the SqlCommand executes.

.PARAMETER CommandText
The Transact-SQL statement, table name or stored procedure to execute at the data source.

.PARAMETER CommandTimeout
The wait time (in seconds) before terminating the attempt to execute a command and generating an error.

.PARAMETER CommandType
Indicates how the CommandText property is to be interpreted. Text is the .NET default.

Text = An SQL text command. (Default.)
StoredProcedure	= The name of a stored procedure.
TableDirect	= The name of a table.

.PARAMETER EnableOptimizedParameterBinding
Indicates whether the command object should optimize parameter performance by disabling Output and InputOutput directions when submitting the command to the SQL Server. The .NET default is False.

.PARAMETER UpdatedRowSource
How command results are applied to the DataRow when used by the Update method of the DbDataAdapter.

None = Any returned parameters or rows are ignored.
OutputParameters = Output parameters are mapped to the changed row in the DataSet.
FirstReturnedRecord	= The data in the first returned row is mapped to the changed row in the DataSet.
Both = Both the output parameters and the first returned row are mapped to the changed row in the DataSet.

.PARAMETER StatementCompleted
Event. Occurs when the execution of a Transact-SQL statement completes.

.INPUTS

.OUTPUTS

.EXAMPLE

#>
function New-DbCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Data.SqlClient.SqlConnection] $Connection,
        [Microsoft.Data.SqlClient.SqlRetryLogicBaseProvider] $RetryLogicProvider,
        [Microsoft.Data.Sql.SqlNotificationRequest] $Notification,
        [Microsoft.Data.SqlClient.SqlTransaction] $Transaction,
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $CommandText,
        [int] $CommandTimeout,
        [System.Data.CommandType] $CommandType,
        [bool] $EnableOptimizedParameterBinding,
        [System.Data.UpdateRowSource] $UpdatedRowSource,
        [System.Management.Automation.PSEvent] $StatementCompleted,

        [Hashtable] $SqlParameters = @{}
    )

    begin {

    }

    process {
        $sqlCommand = New-Object Microsoft.Data.SqlClient.SqlCommand

        if ($PSBoundParameters.ContainsKey("Connection")) { $sqlCommand.Connection = $Connection }
        if ($PSBoundParameters.ContainsKey("RetryLogicProvider")) { $sqlCommand.RetryLogicProvider = $RetryLogicProvider }
        if ($PSBoundParameters.ContainsKey("Notification")) { $sqlCommand.Notification = $Notification }
        if ($PSBoundParameters.ContainsKey("Transaction")) { $sqlCommand.Transaction = $Transaction }
        if ($PSBoundParameters.ContainsKey("CommandText")) { $sqlCommand.CommandText = $CommandText }
        if ($PSBoundParameters.ContainsKey("CommandTimeout")) { $sqlCommand.CommandTimeout = $CommandTimeout }
        if ($PSBoundParameters.ContainsKey("CommandType")) { $sqlCommand.CommandType = $CommandType }
        if ($PSBoundParameters.ContainsKey("EnableOptimizedParameterBinding")) { $sqlConnection.EnableOptimizedParameterBinding = $EnableOptimizedParameterBinding }
        if ($PSBoundParameters.ContainsKey("UpdatedRowSource")) { $sqlConnection.UpdatedRowSource = $UpdatedRowSource }
        if ($PSBoundParameters.ContainsKey("StatementCompleted")) { $sqlConnection.StatementCompleted = $StatementCompleted }

        foreach ($sqlParameterName in $SqlParameters.Keys) {
            # It's not safe to call the shortcut constructor because of boxing issues
            if ($SqlParameters[$sqlParameterName] -is [Microsoft.Data.SqlClient.SqlParameter]) {
                $sqlParameter = $SqlParameters[$sqlParameterName]
            } else {
                $sqlParameter = New-Object Microsoft.Data.SqlClient.SqlParameter
                $sqlParameter.ParameterName = $sqlParameterName
                $sqlParameter.Value = $SqlParameters[$sqlParameterName]
            }
            if ($null -eq $sqlParameter.Value) {
                $sqlParameter.Value = [DBNull]::Value
            }
            [void] $sqlCommand.Parameters.Add($sqlParameter)
        }

        $sqlCommand
    }

    end {

    }
}
