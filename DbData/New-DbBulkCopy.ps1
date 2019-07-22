<#

.SYNOPSIS
Efficiently bulk loads data into a SQL Server table.

.DESCRIPTION
Bulk loads data. Input columns do not need to be in the same order as the destination table as mapping is done.

.PARAMETER InputObject
A connection string, SqlConnection, SqlCommand, or SqlTransaction.

.PARAMETER Data
A DataSet or a DataTable (such as from Get-DbData).

.PARAMETER Timeout
Bulk copy timeout.

.PARAMETER PassThru
Pass the input on in the pipeline for further operations.

.PARAMETER Options
A combination of special options from System.Data.SqlClient.SqlBulkCopyOptions.

.INPUTS
Pipe in the output of Get-DbData or similar.

.OUTPUTS
(Optionally) Whatever was piped in.

.EXAMPLE
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance | New-DbCommand "If Object_Id('dbo.Moo', 'U') Is Not Null Drop Table dbo.Moo; Create Table dbo.Moo (A Int Identity (1, 1) Primary Key, B Nvarchar(Max)); Dbcc Checkident('dbo.Moo', Reseed, 100);" | Get-DbData -As NonQuery | Out-Null
$dbData = New-DbConnection $serverInstance | New-DbCommand "Select * From dbo.Moo;" | Get-DbData -As DataTables -TableMapping @("Moo")
$dbData.Alter(@{ B = "A" }) | Out-Null
$dbData.Alter(@{ B = "B" }) | Out-Null
$dbData.Alter(@{ A = 100; B = "C" }) | Out-Null
$dbData.Alter(@{ B = "D" }) | Out-Null
New-DbConnection $serverInstance | New-DbCommand "Truncate Table dbo.Moo;" | Get-DbData -As NonQuery | Out-Null
New-DbConnection $serverInstance | New-DbBulkCopy -Data $dbData -Option "KeepIdentity"
New-DbConnection $serverInstance | New-DbCommand "Select * From dbo.Moo;" | Get-DbData

.NOTES

#>

function New-DbBulkCopy {
    [CmdletBinding()]
    [system.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Alias("SqlTransaction")]
        [Alias("SqlCommand")]
        [Alias("SqlConnection")]
        [Alias("ConnectionString")]
        $InputObject,

        # Data in either a DataSet or DataTable.
        [Alias("DataSet")]
        [Alias("DataTable")]
        $Data,

        [System.Data.SqlClient.SqlBulkCopyOptions] $Options = [System.Data.SqlClient.SqlBulkCopyOptions]::Default,
        $Timeout,
        [switch] $PassThru
    )

    begin {
    }

    process {
        Use-DbRetry {
            $closeConnection = $false

            try {
                if ($InputObject -is [string]) {
                    $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($InputObject, $Options)
                } elseif ($InputObject -is [System.Data.SqlClient.SqlConnection]) {
                    if ($InputObject.State -ne "Open") {
                        $InputObject.Open()
                        $closeConnection = $true
                    }

                    $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($InputObject, $Options, $null)
                } elseif ($InputObject -is [System.Data.SqlClient.SqlCommand]) {
                    if ($InputObject.Connection.State -ne "Open") {
                        $InputObject.Connection.Open()
                        $closeConnection = $true
                    }

                    $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($InputObject.Connection, $Options, $InputObject.Transaction)
                } else {
                    Write-Error "InputObject was $($InputObject.GetType().FullName) which is an unsupported type"
                }

                if ($Timeout) {
                    $bulkCopy.BulkCopyTimeout = $Timeout
                }

                if ($Data -is [System.Data.DataSet]) {
                    $tables = $Data.Tables
                } else {
                    $tables = , $Data
                }

                foreach ($table in $tables) {
                    $bulkCopy.DestinationTableName = $table.TableName

                    # Required in case we've added columns, they will not be in order, and as long As you specify the names here it will all work okay
                    $bulkCopy.ColumnMappings.Clear()
                    $table.Columns | ForEach-Object {
                        [void] $bulkCopy.ColumnMappings.Add((New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping($_.ColumnName, $_.ColumnName)))
                    }
                    $bulkCopy.WriteToServer($table)
                }
                $bulkCopy.Close()
            } finally {
                if ($closeConnection) {
                    if ($InputObject -is [System.Data.SqlClient.SqlConnection] -and $InputObject.State -eq "Open") {
                        $InputObject.Close()
                    } elseif ($InputObject -is [System.Data.SqlClient.SqlCommand] -and $InputObject.Connection.State -eq "Open") {
                        $InputObject.Connection.Close()
                    }
                }
            }
        }
        if ($PassThru) {
            $InputObject
        }
    }

    end {
    }
}
