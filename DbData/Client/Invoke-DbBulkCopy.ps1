<#

.SYNOPSIS
Lets you efficiently bulk load a SQL Server table with data from another source.

.DESCRIPTION


.PARAMETER BatchSize
Number of rows in each batch. At the end of each batch, the rows in the batch are sent to the server.

.PARAMETER BulkCopyTimeout
Number of seconds for the operation to complete before it times out.

.PARAMETER EnableStreaming
Enables or disables a SqlBulkCopy object to stream data from an IDataReader object. The .NET default is False.

.PARAMETER DestinationTableName
Name of the destination table on the server.

.PARAMETER NotifyAfter
Defines the number of rows to be processed before generating a notification event.

.PARAMETER SqlRowsCopied
Event. Occurs every time that the number of rows specified by the NotifyAfter property have been processed.

.INPUTS

.OUTPUTS

.EXAMPLE

#>
function Invoke-DbBulkCopy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Data.SqlClient.SqlConnection] $Connection,
        [Microsoft.Data.SqlClient.SqlBulkCopyOptions] $CopyOptions = [Microsoft.Data.SqlClient.SqlBulkCopyOptions]::Default,
        [Microsoft.Data.SqlClient.SqlTransaction] $Transaction,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $Data,

        [int] $BatchSize,
        [int] $BulkCopyTimeout,
        [bool] $EnableStreaming,
        [string] $DestinationTableName,
        [int] $NotifyAfter,
        [System.Management.Automation.PSEvent] $SqlRowsCopied
    )

    begin {

    }

    process {
        $sqlBulkCopy = New-Object Microsoft.Data.SqlClient.SqlBulkCopy($Connection, $CopyOptions, $Transaction)

        if ($PSBoundParameters.ContainsKey("BatchSize")) { $sqlBulkCopy.BatchSize = $BatchSize }
        if ($PSBoundParameters.ContainsKey("BulkCopyTimeout")) { $sqlBulkCopy.BulkCopyTimeout = $BulkCopyTimeout }
        if ($PSBoundParameters.ContainsKey("EnableStreaming")) { $sqlBulkCopy.EnableStreaming = $EnableStreaming }
        if ($PSBoundParameters.ContainsKey("DestinationTableName")) { $sqlBulkCopy.DestinationTableName = $DestinationTableName }
        if ($PSBoundParameters.ContainsKey("NotifyAfter")) { $sqlBulkCopy.NotifyAfter = $NotifyAfter }
        if ($PSBoundParameters.ContainsKey("SqlRowsCopied")) { $sqlBulkCopy.SqlRowsCopied = $SqlRowsCopied }

        $originalConnectionState = $Connection.State
        try {
            if ($originalConnectionState -ne "Open") {
                $Connection.Open()
            }

            if ($Data -is [System.Data.DataSet]) {
                $dataTables = $Data.Tables
            } else {
                $dataTables = , $Data
            }

            foreach ($dataTable in $dataTables) {
                if (-not $PSBoundParameters.ContainsKey("DestinationTableName")) {
                    $sqlBulkCopy.DestinationTableName = $dataTable.TableName
                }

                # Required in case we've added columns, they will not be in order, and as long As you specify the names here it will all work okay
                $sqlBulkCopy.ColumnMappings.Clear()
                $dataTable.Columns | ForEach-Object {
                    [void] $sqlBulkCopy.ColumnMappings.Add((New-Object Microsoft.Data.SqlClient.SqlBulkCopyColumnMapping($_.ColumnName, $_.ColumnName)))
                }
                $sqlBulkCopy.WriteToServer($dataTable)
            }
            $sqlBulkCopy.Close()
        } finally {
            if ($originalConnectionState -ne "Open" -and $Connection.State -eq "Open") {
                $Connection.Close()
            }
        }
    }

    end {

    }
}
