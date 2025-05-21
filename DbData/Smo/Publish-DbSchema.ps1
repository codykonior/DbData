<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Publish-DbSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Microsoft.Data.SqlClient.SqlConnection] $Connection,

        [string] $DatabaseName,
        [ValidateNotNullOrEmpty()]
        [string] $SchemaName = "dbo",

        [Parameter(Mandatory)]
        [System.Data.DataSet] $DataSet,

        [switch] $Temporal,
        [switch] $Script
    )

    begin {
    }

    process {
        $originalConnectionState = $Connection.State
        try {
            $scriptText = New-Object System.Collections.Generic.List[string]
            $server = $Connection | Get-DbServer -WarningAction SilentlyContinue
            if (-not $PSBoundParameters.ContainsKey("DatabaseName")) {
                $DatabaseName = $server.ConnectionContext.DatabaseName
            }
            $database = $server.Databases[$DatabaseName]
            $schema = New-Object Microsoft.SqlServer.Management.Smo.Schema($database, $schemaName)
            $schema.Refresh()
            if ($Script) {
                Write-Verbose "Script Schema [$($schema.Name)]"
                $scriptText.Add($schema.Script(@{ IncludeIfNotExists = $true }))
            } elseif ($schema.State -ne "Existing") {
                Write-Verbose "Create Schema [$($schema.Name)]"
                $schema.Create()
            } else {
                Write-Verbose "Existing Schema [$($schema.Name)]"
            }

            $tables = [ordered] @{}
            foreach ($dataTable in $DataSet.Tables) {
                $table = New-Object Microsoft.SqlServer.Management.Smo.Table($database, $dataTable.TableName, $SchemaName)
                $table.Refresh()

                if ($Temporal -and $table.Columns.Count -eq 0 -and $server.Version.Major -ge 13) {
                    Write-Verbose "Adding Temporal Fields"

                    $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType("DateTime2", 2)
                    $fromColumn = New-Object Microsoft.SqlServer.Management.Smo.Column($table, "_ValidFrom", $dataType)
                    $fromColumn.Nullable = $false # Columns belonging to a system-time period cannot be nullable.
                    $fromColumn.IsHidden = $true
                    $fromColumn.GeneratedAlwaysType = "AsRowStart"
                    $table.Columns.Add($fromColumn)

                    $toColumn = New-Object Microsoft.SqlServer.Management.Smo.Column($table, "_ValidTo", $dataType)
                    $toColumn.Nullable = $false # Columns belonging to a system-time period cannot be nullable.
                    $toColumn.IsHidden = $true
                    $toColumn.GeneratedAlwaysType = "AsRowEnd"
                    $table.Columns.Add($toColumn)

                    $table.AddPeriodForSystemTime("_ValidFrom", "_ValidTo", $true) # If you accidentally passed non strings you get a "must provide existing column" error

                    $table.HistoryTableSchema = $SchemaName
                    $table.HistoryTableName = "$($dataTable.TableName)_History"
                    $table.IsSystemVersioned = $true
                }

                # Iterate data table columns where the names are not in the physical table
                $hasTableChanged = $false
                foreach ($dataTableColumn in ($dataTable.Columns | Where-Object { $_.ColumnName -notin ($table.Columns | Select-Object -ExpandProperty Name) })) {
                    $hasTableChanged = $true
                    <#
                    https://learn.microsoft.com/en-us/dotnet/api/system.data.datacolumn.datatype?view=net-9.0

                        Boolean
                        Byte
                        Byte[]
                        Char
                        DateOnly
                        DateTime
                        Decimal
                        Double
                        Guid
                        Int16
                        Int32
                        Int64
                        SByte
                        Single
                        String
                        TimeOnly
                        TimeSpan
                        UInt16
                        UInt32
                        UInt64

                    https://learn.microsoft.com/en-us/sql/connect/ado-net/sql-server-data-type-mappings?view=sql-server-ver16
                    [Enum]::GetValues([Microsoft.SqlServer.Management.Smo.SqlDataType])

                    #>
                    $dataType = switch ($dataTableColumn.DataType.Name) {
                        "Boolean" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::Bit }
                        "Byte" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::TinyInt }
                        "Byte[]" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::VarBinary }
                        "Char" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::NChar }
                        "DateOnly" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::Date }
                        "DateTime" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::DateTime2 }
                        "Decimal" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::Decimal }
                        "Double" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::Float }
                        "Guid" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::UniqueIdentifier }
                        "Int16" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::SmallInt }
                        "Int32" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::Int }
                        "Int64" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::BigInt }
                        "SByte" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::SmallInt }
                        "Single" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::Decimal }
                        "String" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::NVarChar }
                        "TimeOnly" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::Time }
                        "TimeSpan" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::Time }
                        "UInt16" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::SmallInt }
                        "UInt32" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::BigInt }
                        "UInt64" { [Microsoft.SqlServer.Management.Smo.SqlDataType]::BigInt }
                        default {
                            # This basically defaults everything else so that if we passed something we really
                            # didn't expect then we won't be storing a raw object; it'll be cast to string.
                            [Microsoft.SqlServer.Management.Smo.SqlDataType]::NVarChar
                        }
                    }
                    Write-Verbose "Adding table [$($dataTable.TableName)] column [$($dataTableColumn.ColumnName)] as [$dataType]"

                    if ($dataType -eq "VarBinary" -or $dataType -eq "VarChar" -or $dataType -eq "NVarChar") {
                        if ($dataTableColumn.MaxLength -ne -1) {
                            $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($dataType, $dataTableColumn.MaxLength)
                        } else {
                            $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType("$($dataType)Max")
                        }
                    } elseif ($dataType -eq "Decimal") {
                        # Change the default from 18 to 25 which is big enough to store LSNs
                        $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($dataType, 25, 4)
                    } else {
                        $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($dataType)
                    }

                    $column = New-Object Microsoft.SqlServer.Management.Smo.Column($table, $dataTableColumn.ColumnName, $dataType)
                    $column.Nullable = $dataTableColumn.AllowDbNull
                    $table.Columns.Add($column)
                }
                $tables.($dataTable.TableName) = $table

                # If the SMO table has a primary key but the new/existing table doesn't
                if ($dataTable.PrimaryKey) {
                    if (-not ($table.Indexes | Where-Object { $_.IndexKeyType -eq "DriPrimaryKey" })) {
                        $hasTableChanged = $true

                        $primaryKeyConstraintName = $dataTable.Constraints | Where-Object { $_ -is [System.Data.UniqueConstraint] -and $_.IsPrimaryKey } | Select-Object -ExpandProperty ConstraintName
                        Write-Verbose "Adding table [$($dataTable.TableName) primary key [$primaryKeyConstraintName]"

                        $primaryKeyIndex = New-Object Microsoft.SqlServer.Management.Smo.Index($table, $primaryKeyConstraintName)
                        $primaryKeyIndex.IndexType = [Microsoft.SqlServer.Management.Smo.IndexType]::ClusteredIndex
                        $primaryKeyIndex.IndexKeyType = [Microsoft.SqlServer.Management.Smo.IndexKeyType]::DriPrimaryKey

                        foreach ($dataTableColumn in $dataTable.PrimaryKey) {
                            $primaryKeyIndexColumn = New-Object Microsoft.SqlServer.Management.Smo.IndexedColumn($primaryKeyIndex, $dataTableColumn.ColumnName)
                            $primaryKeyIndex.IndexedColumns.Add($primaryKeyIndexColumn)
                        }

                        $table.Indexes.Add($primaryKeyIndex)
                    }
                } else {
                    Write-Verbose "Table [$($table.Name)] does not have a primary key."
                }

                if ($hasTableChanged) {
                    # You must script out the table, the primary key, and the foreign keys separately
                    if ($Script) {
                        Write-Verbose "Script Table [$($table.Name)]"
                        $scriptText.Add($table.Script(@{ IncludeIfNotExists = $true; DriAll = $true; }))
                        foreach ($index in $table.Indexes) {
                            $scriptText.Add($index.Script(@{ IncludeIfNotExists = $true; DriAll = $true; }))
                        }
                    } else {
                        if ($table.State -eq "Existing") {
                            Write-Verbose "Alter Table [$($table.Name)]"
                            $table.Alter()
                            foreach ($index in $table.Indexes) {
                                Write-Verbose "Alter Index $($index.Name)"
                                $index.Alter()
                            }
                        } else {
                            Write-Verbose "Create Table [$($dataTable.TableName)]"
                            $table.Create()
                            foreach ($index in $table.Indexes) {
                                Write-Verbose "Create Index $($index.Name)"
                                $index.Alter()
                            }
                        }
                    }
                }
            }

            foreach ($dataTable in $DataSet.Tables) {
                $table = New-Object Microsoft.SqlServer.Management.Smo.Table($database, $dataTable.TableName, $SchemaName)
                $table.Refresh() # This will fill the schema from the database

                foreach ($constraint in ($dataTable.Constraints | Where-Object { $_ -is [System.Data.ForeignKeyConstraint] -and $_.ConstraintName -notin ($table.ForeignKeys | Select-Object -ExpandProperty Name) })) {
                    $constraintName = $constraint.ConstraintName
                    Write-Verbose "Adding Table [$($dataTable.TableName)] Constraint [$constraintName]"

                    $foreignKey = New-Object Microsoft.SqlServer.Management.Smo.ForeignKey($tables.($dataTable.TableName), $constraintName)
                    $foreignKey.ReferencedTable = $constraint.RelatedTable.TableName
                    $foreignKey.ReferencedTableSchema = $SchemaName
                    $foreignKey.IsChecked = $true
                    for ($i = 0; $i -lt $constraint.Columns.Count; $i++) {
                        $foreignKeyColumn = New-Object Microsoft.SqlServer.Management.Smo.ForeignKeyColumn($foreignKey, $constraint.Columns[$i], $constraint.RelatedColumns[$i])
                        $foreignKey.Columns.Add($foreignKeyColumn)
                    }

                    # SQL 2017 supports on Delete Cascade with Temporal Tables
                    if ($Temporal -and $server.Version.Major -ge 14) {
                        $foreignKey.DeleteAction = "Cascade"
                    }

                    if ($Script) {
                        $scriptText.Add($foreignKey.Script(@{ IncludeIfNotExists = $true }))
                    } else {
                        Write-Verbose "Add Table [$($dataTable.TableName)] Foreign Key [$($foreignKey.Name)]"
                        $foreignKey.Create()
                    }
                }
            }

            if ($Script) {
                $scriptText -join [Environment]::NewLine
            }
        } finally {
            if ($originalConnectionState -ne "Open" -and $Connection.State -eq "Open") {
                $Connection.Close()
            }
        }
    }

    end {
    }
}
