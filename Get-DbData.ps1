<#

.SYNOPSIS
Execute a command against a SQL Server instance.

.DESCRIPTION
Executes a command with output sent to the Verbose stream. Commands can be non-queries, scalars, or return rows (the default), data tables, or a data set.

For data tables and dataset, if the command is a simple Select statement against a single table (and optional simple Where clause), then Insert and Update/Delete statements (if a PK exists) are generated and an Alter() function added to the first data table.

This can then be executed to trigger deletions (after modifying the rows in the table), or upserts (by passing in a hash table of column names and values).

.PARAMETER SqlCommand.
A SqlCommand likely from New-DbCommand.

.PARAMETER TableMapping
An optional list of custom table names to use for the result set, in order. By default these are Table, Table1, Table2, etc.

.PARAMETER OutputAs
The type of data to return. It can be scalar (the first column of the first row of a result set), a non query (an integer), datarows, datatables, or a dataset.

.PARAMETER NoSchema
For some simple operations, where no editing is required, you might want to skip schema gathering.

.PARAMETER NoCommandBuild
For some simple operations, where no editing is required, you might want to skip command building.

.INPUTS
Pipe in an SqlCommand like from New-DbCommand.

.OUTPUTS
See the OutputAs parameter.

.EXAMPLE
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance master | New-DbCommand "If Object_Id('dbo.Moo', 'U') Is Not Null Drop Table dbo.Moo; Create Table dbo.Moo (A Int Identity (1, 1) Primary Key, B Nvarchar(Max)); Dbcc Checkident('dbo.Moo', Reseed, 100);" | Get-DbData -OutputAs NonQuery | Out-Null
$dbData = New-DbConnection $serverInstance master | New-DbCommand "Select * From dbo.Moo;" | Get-DbData -OutputAs DataTables
$dbData.Alter(@{ B = "A" }) | Out-Null
$dbData.Alter(@{ B = "B" }) | Out-Null
$dbData.Alter(@{ A = 100; B = "C" }) | Out-Null
$dbData.Alter(@{ A = 4; B = "D" }) | Out-Null

Results:

  A B
  - -
100 C
101 B
102 D

This drops and creates a dummy table with an identity column seeding at 100. It then inserts two rows, updates the first row, then attempts a fixed identity insert.

The result is three rows, with the special identity of the last column discarded (but the properly allocated identity value returned).

#>

function Get-DbData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [string[]] $TableMapping = @(),
        
        [ValidateSet("NonQuery", "Scalar", "DataRows", "DataSet", "DataTables")]
        $OutputAs = "DataRows",

        [switch] $NoSchema,
        [switch] $NoCommandBuilder,

        $infoMessageOutput = (New-Object Collections.ArrayList)
    )

    begin {
        $infoMessageScript = {
            Set-StrictMode -Version Latest
            $ErrorActionPreference = "Stop"

            # Write-Error has been substituted for Write-Verbose here because otherwise it gets lost
            try {
                $_ | Select-Object -ExpandProperty Errors | ForEach-Object {
                    [void] $infoMessageOutput.Add($_)

                    if ($_.Class -le 10) {
                        "Msg {0}, Level {1}, State {2}, Line {3}$([Environment]::NewLine){4}" -f $_.Number, $_.Class, $_.State, $_.LineNumber, $_.Message | Write-Verbose
                    } else {
                        # Should be Write-Error but it doesn't seem to trigger properly (after -FireInfoMessageEventOnUserErrors) and so it would otherwise up getting lost
                        "Msg {0}, Level {1}, State {2}, Line {3}$([Environment]::NewLine){4}" -f $_.Number, $_.Class, $_.State, $_.LineNumber, $_.Message | Write-Verbose
                    }
                }
            } catch {
                $_ | Write-Verbose
            }
        }.GetNewClosure()

        # I know this isn't beautiful or awesome and I've forgotten how it works.
        # But it does work most of the time.
        $alterScript = {
            [CmdletBinding()]
            param (
                $DataRows
            )
            # Process multiple rows one at a time
            foreach ($row in $DataRows) {
                $table = $this
            
                # Get the incoming column names
                if ($row -is [System.Data.DataRow]) {
                    $rowName = $row.Table.Columns | Select-Object -ExpandProperty ColumnName
                } elseif ($row -is [Hashtable]) {
                    $rowName = $row.Keys
                } elseif ($row -is [PSObject]) {
                    $newRow = @{}
                    $row.psobject.Properties | ForEach-Object {
                        $newRow.Add($_.Name, $_.Value)
                    }
                    $row = $newRow
                    $rowName = $row.Keys
                } else {
                    Write-Error "Unknown row type of $($row.GetType().FullName)"
                }

                # Get the primary key names and values, if any
                $pkName = $table.PrimaryKey | Select-Object -ExpandProperty ColumnName

                $pkValue = New-Object Collections.ArrayList
                foreach ($name in $pkName) {
                    if ($rowName -contains $name) {
                        [void] $pkValue.Add($row[$name])
                    } else {
                        $pkValue = $null
                        break
                    }
                }

                if ($pkValue) {
                    $newRow = $table.Rows.Find($pkValue.ToArray())
                } else {
                    $newRow = $null
                }

                if ($newRow) {
                    foreach ($property in ($rowName | Where-Object { $pkName -notcontains $_ })) {
                        if ($newRow[$property] -ne $row[$property]) {
                            if ($null -ne $row[$property]) {
                                $newRow[$property] = $row[$property]
                            } else {
                                $newRow[$property] = [DBNull]::Value
                            }
                        }
                    }
                } else {
                    $newRow = $table.NewRow()
                    foreach ($property in $rowName) {
                        if ($null -ne $row[$property]) {
                            $newRow[$property] = $row[$property]
                        } else {
                            $newRow[$property] = [DBNull]::Value
                        }
                    }

                    $table.Rows.Add($newRow)
                }
            }

            $this.SqlDataAdapter.Update($this)
        }
    }

    process {
        $infoMessageOutput = New-Object Collections.ArrayList
        $SqlCommand.Connection.add_InfoMessage($infoMessageScript)

        try {
            $closeConnection = $false
            if ($SqlCommand.Connection.State -ne "Open") {
                $SqlCommand.Connection.Open()
                $closeConnection = $true
            }

            switch ($OutputAs) {
                "Scalar" {
                    $scalar = $SqlCommand.ExecuteScalar()
                    break
                }
                "NonQuery" {
                    $nonQuery = $SqlCommand.ExecuteNonQuery()
                    break
                }
                default {
                    $sqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCommand)
                    $sqlDataAdapter.MissingSchemaAction = "AddWithKey"

                    # Name the tables if they were passed in
                    for ($i = 0; $i -lt $TableMapping.Count; $i++) {
                        [void] $sqlDataAdapter.TableMappings.Add("Table$(if ($i -ne 0) { $i })", $TableMapping[$i])
                    }

                    $dataSet = New-Object System.Data.DataSet
                    if (!$NoSchema) {
                        try {
                            [void] $sqlDataAdapter.FillSchema($dataSet, [System.Data.SchemaType]::Mapped)
                        } catch {
                            # Swallow. We can't write it verbosely because verbose is used for print statements.
                            # Write-Verbose "You can't edit this data: $_"
                        }
                    }
                    
                    [void] $sqlDataAdapter.Fill($dataSet)        

                    # Add Insert/Update/Delete commands
                    if ($OutputAs -ne "DataRows" -and !$NoCommandBuilder -and $dataSet.Tables.Count -ne 0) {
                        try {
                            New-DisposableObject ($commandBuilder = New-Object System.Data.SqlClient.SqlCommandBuilder($sqlDataAdapter)) {
                                # Insert commands are the most likely to generate because they don't need a PK
                                $sqlDataAdapter.InsertCommand = $commandBuilder.GetInsertCommand().Clone()
                                if ($identityColumn = $dataSet.Tables[0].Columns | Where-Object { $_.AutoIncrement -eq $true }) {
                                    $sqlDataAdapter.InsertCommand.CommandText += "; Select @Id = Scope_Identity();"
                                    $sqlDataAdapter.InsertCommand.Parameters.Add("@Id", [System.Data.SqlDbType]::BigInt, 0, $identityColumn.ColumnName).Direction = "Output"
                                    $sqlDataAdapter.InsertCommand.UpdatedRowSource = "OutputParameters"
                                }

                                # These will fail on tables without a PK
                                $sqlDataAdapter.DeleteCommand = $commandBuilder.GetDeleteCommand().Clone()
                                $sqlDataAdapter.UpdateCommand = $commandBuilder.GetUpdateCommand().Clone()
                            }
                        } catch { 
                            # Swallow. We can't write it verbosely because verbose is used for print statements.
                            # Write-Verbose "You can't edit this data: $_"
                        }
                        
                        if ($sqlDataAdapter.InsertCommand -or $sqlDataAdapter.UpdateCommand -or $sqlDataAdapter.DeleteCommand) {
                            # Store a link to the data adapter against the first table along with the alter script
                            Add-Member -InputObject $dataSet.Tables[0] -MemberType NoteProperty -Name SqlDataAdapter -Value $sqlDataAdapter
                            Add-Member -InputObject $dataSet.Tables[0] -MemberType ScriptMethod -Name Alter -Value $alterScript
                        }
                    }
                }
            }
                
            switch ($OutputAs) {
                "NonQuery" {
                    $nonQuery
                    break
                }
                "Scalar" {
                    $scalar
                    break
                }
                "DataRows" {
                    $dataSet.Tables | Select-Object -ExpandProperty Rows
                    break
                }
                "DataSet" {
                    $dataSet
                    break
                }
                default {
                    $dataSet.Tables
                    break
                }
            }
        } finally {
            if ($closeConnection -and $SqlCommand.Connection.State -eq "Open") {
                $SqlCommand.Connection.Close()
            }
            [void] $SqlCommand.Connection.remove_InfoMessage($infoMessageScript)
        }
    }

    end {
    }
}
