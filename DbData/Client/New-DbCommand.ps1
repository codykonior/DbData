<#
.PARAMETER Connection


.PARAMETER RetryLogicProvider


.PARAMETER Notification


.PARAMETER Transaction


.PARAMETER CommandText


.PARAMETER CommandTimeout


.PARAMETER CommandType


.PARAMETER DesignTimeVisible


.PARAMETER EnableOptimizedParameterBinding


.PARAMETER UpdatedRowSource


.PARAMETER StatementCompleted
Event.

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
        if ($PSBoundParameters.ContainsKey("DesignTimeVisible")) { $sqlCommand.DesignTimeVisible = $DesignTimeVisible }
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
