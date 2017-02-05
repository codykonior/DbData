function New-DbBulkCopy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $SqlObject, # Connection String, Connection, or Transaction (which is a Command))

        # Data in either a DataSet or DataTable.
        [Alias("DataSet")]
        [Alias("DataTable")]
        $Data,

        $Timeout,
        [switch] $PassThru
    )

    begin {
    }

    process {
        Use-DbRetry {
            if ($SqlObject -is [string] -or $SqlObject -is [System.Data.SqlClient.SqlConnection]) {
                $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($SqlObject, [System.Data.SqlClient.SqlBulkCopyOptions]::Default)
            } elseif ($SqlObject -is [System.Data.SqlClient.SqlCommand]) {
                $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($SqlObject.Connection, [System.Data.SqlClient.SqlBulkCopyOptions]::Default, $SqlObject.Transaction)
            } else {
                Write-Error "Unknown input type $($SqlObject.GetType().FullName)"
            }

            if ($Timeout) {
                $bulkCopy.BulkCopyTimeout = $Timeout
            }

            if ($Data -is [System.Data.DataSet]) {
                $tables = $Data.Tables
            } else {
                $tables = ,$Data
            }

            foreach ($table in $tables) {
                $bulkCopy.DestinationTableName = $table.TableName

                # Required in case we've added columns, they will not be in order, and as long As you specify the names here it will all work okay
                $bulkCopy.ColumnMappings.Clear()
                $table.Columns | %{ 
                    [void] $bulkCopy.ColumnMappings.Add((New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping($_.ColumnName, $_.ColumnName)))
                }
                $bulkCopy.WriteToServer($table)
            }
            $bulkCopy.Close()
        }

        if ($PassThru) {
            $SqlObject
        }
    }

    end {
    }
}
