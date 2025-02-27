<#
.PARAMETER SqlCommand


.PARAMETER TableMapping

.PARAMETER OutputAs


--


.PARAMETER DeleteCommand


.PARAMETER InsertCommand


.PARAMETER SelectCommand


.PARAMETER UpdateCommand


.PARAMETER UpdateBatchSize


.PARAMETER AcceptChangesDuringFill


.PARAMETER AcceptChangesDuringUpdate


.PARAMETER ContinueUpdateOnError


.PARAMETER FillLoadOption


.PARAMETER MissingMappingAction


.PARAMETER MissingSchemaAction


.PARAMETER ReturnProviderSpecificTypes


.PARAMETER RowUpdated
Event.

.PARAMETER RowUpdating
Event.


.PARAMETER FillError
Event.

.PARAMETER Disposed
Event.

.PARAMETER SchemaType

#>
function Invoke-DbCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Microsoft.Data.SqlClient.SqlCommand] $SqlCommand,
        [string[]] $TableMapping = @(),

        [ValidateSet("NonQuery", "Scalar", "DataRow", "DataSet", "DataTable", "PSCustomObject")]
        [ValidateNotNullOrEmpty()]
        [Alias("As")]
        $OutputAs = "PSCustomObject",

        [Microsoft.Data.SqlClient.SqlCommand] $DeleteCommand,
        [Microsoft.Data.SqlClient.SqlCommand] $InsertCommand,
        [Microsoft.Data.SqlClient.SqlCommand] $SelectCommand,
        [Microsoft.Data.SqlClient.SqlCommand] $UpdateCommand,
        [int] $UpdateBatchSize,
        [bool] $AcceptChangesDuringFill,
        [bool] $AcceptChangesDuringUpdate,
        [bool] $ContinueUpdateOnError,
        [System.Data.LoadOption] $FillLoadOption,
        [System.Data.MissingMappingAction] $MissingMappingAction,
        [System.Data.MissingSchemaAction] $MissingSchemaAction,
        [bool] $ReturnProviderSpecificTypes,
        [System.Management.Automation.PSEvent] $RowUpdated,
        [System.Management.Automation.PSEvent] $RowUpdating,
        [System.Management.Automation.PSEvent] $FillError,
        [System.Management.Automation.PSEvent] $Disposed,

        [System.Data.SchemaType] $SchemaType,

        [switch] $Alter,
        $AlterCollectionSeparator = [Environment]::NewLine
    )

    begin {
        $AlterScriptBlock = {
            [CmdletBinding()]
            param (
                $DataRows
            )
            Set-StrictMode -Version Latest
            $ErrorActionPreference = "Stop"

            $dataTable = $this

            # Process multiple rows one at a time
            foreach ($dataRow in $DataRows) {
                # Get the incoming column names
                if ($dataRow -is [System.Data.DataRow]) {
                    $dataRowColumnNames = $dataRow.Table.Columns | Microsoft.PowerShell.Utility\Select-Object -ExpandProperty ColumnName
                } elseif ($dataRow -is [Hashtable]) {
                    $dataRowColumnNames = $dataRow.Keys
                } elseif ($dataRow -is [PSObject]) {
                    $replaceDataRow = @{ }
                    $dataRow.psobject.Properties | Microsoft.PowerShell.Core\ForEach-Object {
                        $replaceDataRow.($_.Name) = $_.Value
                    }
                    $dataRow = $replaceDataRow
                    $dataRowColumnNames = $dataRow.Keys
                } else {
                    Write-Error "Table [$($dataTable.TableName)] received unknown rows of type [$($dataRow.GetType().FullName)]"
                }

                # Get the primary key column names and values, if any
                $primaryKeyColumnNames = $dataTable.PrimaryKey | Microsoft.PowerShell.Utility\Select-Object -ExpandProperty ColumnName

                $primaryKeyValue = New-Object System.Collections.Generic.List[object]
                foreach ($primaryKeyColumnName in $primaryKeyColumnNames) {
                    if ($primaryKeyColumnName -in $dataRowColumnNames) {
                        $primaryKeyValue.Add($dataRow.$primaryKeyColumnName)
                    } else {
                        $primaryKeyValue = $null
                        break
                    }
                }

                if ($primaryKeyValue -and ($existingDataRow = $dataTable.Rows.Find($primaryKeyValue.ToArray()))) {
                    # Get properties which are not part of the primary key (as those can't be changed)
                    foreach ($dataRowColumnName in ($dataRowColumnNames | Where-Object { $_ -notin $primaryKeyColumnNames })) {
                        if ($dataRow[$dataRowColumnName] -is [System.Collections.ICollection] -and $dataRow[$dataRowColumnName] -isnot [byte[]]) {
                            $dataRowIsNullOrEmpty = $dataRow[$dataRowColumnName].Count -eq 0
                            $dataRowValue = $dataRow[$dataRowColumnName] -join $AlterCollectionSeparator
                        } else {
                            $dataRowIsNullOrEmpty = $null -eq $dataRow[$dataRowColumnName]
                            $dataRowValue = $dataRow[$dataRowColumnName]
                        }

                        if ($existingDataRow[$dataRowColumnName] -ne $dataRowValue) {
                            if ($dataRowIsNullOrEmpty) {
                                if ($existingDataRow[$dataRowColumnName] -isnot [DBNull]) {
                                    $existingDataRow[$dataRowColumnName] = [DBNull]::Value <# Only change it if it actually changed #>
                                }
                            } else {
                                $existingDataRow[$dataRowColumnName] = $dataRowValue
                            }
                        }
                    }
                } else {
                    $newDataRow = $dataTable.NewRow()
                    foreach ($dataRowColumnName in $dataRowColumnNames) {
                        if ($dataRow[$dataRowColumnName] -is [System.Collections.ICollection] -and $dataRow[$dataRowColumnName] -isnot [byte[]]) {
                            $dataRowIsNullOrEmpty = $dataRow[$dataRowColumnName].Count -eq 0
                            $dataRowValue = $dataRow[$dataRowColumnName] -join $AlterCollectionSeparator
                        } else {
                            $dataRowIsNullOrEmpty = $null -eq $dataRow[$dataRowColumnName]
                            $dataRowValue = $dataRow[$dataRowColumnName]
                        }

                        if ($dataRowIsNullOrEmpty) {
                            if ($newDataRow[$dataRowColumnName] -isnot [DBNull]) {
                                $newDataRow[$dataRowColumnName] = [DBNull]::Value
                            }
                        } else {
                            $newDataRow[$dataRowColumnName] = $dataRowValue
                        }
                    }

                    $dataTable.Rows.Add($newDataRow)
                }

                # This must be done here rather than all at once. This is so
                # IDs can be updated after each row - otherwise multiple rows
                # inserted at once will start to error.
                $sqlDataAdapter.Update($dataTable)
            }

            # This is done at the end if we only deleted rows
            if (-not $DataRow) {
                $sqlDataAdapter.Update($this)
            }
        }
    }

    process {
        $originalSqlCommandConnectionState = $SqlCommand.Connection.State
        try {
            if ($originalSqlCommandConnectionState -ne "Open") {
                $SqlCommand.Connection.Open()
            }

            switch ($OutputAs) {
                "NonQuery" {
                    return $SqlCommand.ExecuteNonQuery()
                }
                "Scalar" {
                    $scalar = $SqlCommand.ExecuteScalar()
                    if ($scalar -isnot [DBNull]) {
                        return $scalar
                    } else {
                        return
                    }
                }
            }

            $sqlDataAdapter = New-Object Microsoft.Data.SqlClient.SqlDataAdapter($SqlCommand)
            if ($PSBoundParameters.ContainsKey("DeleteCommand")) { $sqlDataAdapter.DeleteCommand = $DeleteCommand }
            if ($PSBoundParameters.ContainsKey("InsertCommand")) { $sqlDataAdapter.InsertCommand = $InsertCommand }
            if ($PSBoundParameters.ContainsKey("SelectCommand")) { $sqlDataAdapter.SelectCommand = $SelectCommand }
            if ($PSBoundParameters.ContainsKey("UpdateCommand")) { $sqlDataAdapter.UpdateCommand = $UpdateCommand }
            if ($PSBoundParameters.ContainsKey("UpdateBatchSize")) { $sqlDataAdapter.UpdateBatchSize = $UpdateBatchSize }
            if ($PSBoundParameters.ContainsKey("AcceptChangesDuringFill")) { $sqlDataAdapter.AcceptChangesDuringFill = $AcceptChangesDuringFill }
            if ($PSBoundParameters.ContainsKey("AcceptChangesDuringUpdate")) { $sqlDataAdapter.AcceptChangesDuringUpdate = $AcceptChangesDuringUpdate }
            if ($PSBoundParameters.ContainsKey("ContinueUpdateOnError")) { $sqlDataAdapter.ContinueUpdateOnError = $ContinueUpdateOnError }
            if ($PSBoundParameters.ContainsKey("FillLoadOption")) { $sqlDataAdapter.FillLoadOption = $FillLoadOption }
            if ($PSBoundParameters.ContainsKey("MissingMappingAction")) { $sqlDataAdapter.MissingMappingAction = $MissingMappingAction }
            if ($PSBoundParameters.ContainsKey("MissingSchemaAction")) { $sqlDataAdapter.MissingSchemaAction = $MissingSchemaAction }
            if ($PSBoundParameters.ContainsKey("ReturnProviderSpecificTypes")) { $sqlDataAdapter.ReturnProviderSpecificTypes = $ReturnProviderSpecificTypes }
            if ($PSBoundParameters.ContainsKey("RowUpdated")) { $sqlDataAdapter.RowUpdated = $RowUpdated }
            if ($PSBoundParameters.ContainsKey("RowUpdating")) { $sqlDataAdapter.RowUpdating = $RowUpdating }
            if ($PSBoundParameters.ContainsKey("FillError")) { $sqlDataAdapter.FillError = $FillError }
            if ($PSBoundParameters.ContainsKey("Disposed")) { $sqlDataAdapter.Disposed = $Disposed }

            # Name the tables if they were passed in
            for ($i = 0; $i -lt $TableMapping.Count; $i++) {
                [void] $sqlDataAdapter.TableMappings.Add("Table$(if ($i -ne 0) { $i })", $TableMapping[$i])
            }

            $dataSet = New-Object System.Data.DataSet

            if ($PSBoundParameters.ContainsKey("SchemaType")) {
                [void] $sqlDataAdapter.FillSchema($dataSet, $SchemaType)
            } elseif ($Alter) {
                try {
                    $sqlDataAdapter.MissingSchemaAction = "AddWithKey"
                    [void] $sqlDataAdapter.FillSchema($dataSet, [System.Data.SchemaType]::Mapped)
                } catch {
                    $sqlDataAdapter.MissingSchemaAction = "Add"
                    Write-Verbose "FillSchema [$($sqlDataAdapter.SelectCommand.CommandText)] failed with [$_]"
                }
            }

            [void] $sqlDataAdapter.Fill($dataSet)

            # Add Insert/Update/Delete commands
            if ($OutputAs -in @("DataTable", "DataSet") -and $dataSet.Tables.Count -ne 0) {
                try {
                    $sqlCommandBuilder = New-Object Microsoft.Data.SqlClient.SqlCommandBuilder($sqlDataAdapter)
                    # Insert commands are the most likely to generate because they don't need a PK
                    try {
                        $sqlDataAdapter.InsertCommand = $sqlCommandBuilder.GetInsertCommand().Clone()
                        if ($identityColumn = $dataSet.Tables[0].Columns | Where-Object { $_.AutoIncrement -eq $true }) {
                            $sqlDataAdapter.InsertCommand.CommandText += "; Select @Id = Scope_Identity();"
                            $sqlDataAdapter.InsertCommand.UpdatedRowSource = "OutputParameters"
                            $sqlDataAdapter.InsertCommand.Parameters.Add("@Id", [System.Data.SqlDbType]::BigInt, 0, $identityColumn.ColumnName).Direction = "Output"
                        }
                    } catch {
                        Write-Warning $_.Exception.Message
                    }
                    try {
                        # These will fail on tables without a PK
                        $sqlDataAdapter.DeleteCommand = $sqlCommandBuilder.GetDeleteCommand().Clone()
                    } catch {
                        Write-Warning $_.Exception.Message
                    }
                    try {
                        $sqlDataAdapter.UpdateCommand = $sqlCommandBuilder.GetUpdateCommand().Clone()
                    } catch {
                        Write-Warning $_.Exception.Message
                    }
                } finally {
                    if ($null -ne $sqlCommandBuilder) {
                        $sqlCommandBuilder.Dispose()
                    }
                }

                if ($sqlDataAdapter.InsertCommand -or $sqlDataAdapter.UpdateCommand -or $sqlDataAdapter.DeleteCommand) {
                    # Store a link to the data adapter against the first table along with the alter script
                    Add-Member -InputObject $dataSet.Tables[0] -MemberType ScriptMethod -Name Alter -Value $alterScriptBlock.GetNewClosure()
                }
            }

            switch ($OutputAs) {
                "DataRow" {
                    return $dataSet.Tables | Microsoft.PowerShell.Utility\Select-Object -ExpandProperty Rows
                }
                "DataTable" {
                    return $dataSet.Tables
                }
                "PSCustomObject" {
                    foreach ($dataTable in $dataSet.Tables) {
                        foreach ($dataRow in $dataTable.Rows) {
                            $dataRowAsObject = [ordered] @{ }

                            foreach ($columnName in $dataTable.Columns.ColumnName) {
                                if ($dataRow.$columnName -isnot [DBNull]) {
                                    $dataRowAsObject.$columnName = $dataRow.$columnName
                                } else {
                                    $dataRowAsObject.$columnName = $null
                                }
                            }

                            [PSCustomObject] $dataRowAsObject
                        }
                    }
                    return
                }
                "DataSet" {
                    return $dataSet
                }
            }
        } finally {
            if ($originalSqlCommandConnectionState -ne "Open" -and $SqlCommand.Connection.State -eq "Open") {
                $SqlCommand.Connection.Close()
            }
        }

    }

    end {

    }
}
