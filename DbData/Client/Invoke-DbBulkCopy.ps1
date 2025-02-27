<#

.PARAMETER BatchSize


.PARAMETER BulkCopyTimeout


.PARAMETER EnableStreaming


.PARAMETER DestinationTableName


.PARAMETER NotifyAfter


.PARAMETER SqlRowsCopied
Event.

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

        $originalConnectionState = $SqlConnection.State
        try {
            if ($originalConnectionState -ne "Open") {
                $SqlConnection.Open()
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
