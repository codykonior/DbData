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

.PARAMETER InfoMessageVariable
An object of System.Collections.ArrayList which will be appended with all info message objects received while running the command, in addition to formatted versions written to the verbose stream.

.PARAMETER CollectionJoin
A character to join any non-string collections that are passed in when calling .Alter() on a table. For example, for joining @() and ArrayList. Empty collections are converted to DBNull.

.INPUTS
Pipe in an SqlCommand like from New-DbCommand.

.OUTPUTS
See the OutputAs parameter.

.EXAMPLE
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance master | New-DbCommand "If Object_Id('dbo.Moo', 'U') Is Not Null Drop Table dbo.Moo; Create Table dbo.Moo (A Int Identity (1, 1) Primary Key, B Nvarchar(Max)); Dbcc Checkident('dbo.Moo', Reseed, 100);" | Get-DbData -As NonQuery | Out-Null
$dbData = New-DbConnection $serverInstance master | New-DbCommand "Select * From dbo.Moo;" | Get-DbData -As DataTables
$dbData.Alter(@{ B = "AAA" }) | Out-Null
$dbData.Alter(@{ B = @("AAA", "BBB", "CCC") }) | Out-Null
$dbData.Alter(@{ B = @(000, 001, 002) }) | Out-Null
$dbData.Alter(@{ B = @() }) | Out-Null
$dbData.Alter(@{ A = 100; B = "CCC" }) | Out-Null
$dbData.Alter(@{ A = 4; B = "DDD" }) | Out-Null
$dbData | Format-List

Results:
    A : 100
    B : CCC

    A : 101
    B : AAA
        BBB
        CCC

    A : 102
    B : 0
        1
        2

    A : 103
    B : DDD

This drops and creates a dummy table with an identity column seeding at 100. It then inserts a row, two array (collection) rows, updates the first row, then attempts a fixed identity insert.

The result is four rows, with the collections concatenated, and the special identity of the last column discarded (but the properly allocated identity value returned).

.EXAMPLE
$serverInstance = ".\SQL2016"
$infoMessage = New-Object System.Collections.ArrayList
New-DbConnection $serverInstance master | New-DbCommand "Print 'Moo';" | Get-DbData -As NonQuery -InfoMessageVariable $infoMessage | Out-Null
$infoMessage

Results:
    Source     : .Net SqlClient Data Provider
    Number     : 0
    State      : 1
    Class      : 0
    Server     : .\SQL2016
    Message    : Moo
    Procedure  : 
    LineNumber : 1

Stores objects from the message stream into a variable (which is overwritten).

.NOTES
Be careful about supplying additional columns which are not in the destination table. These are ignored.

#>

function Get-DbData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [string[]] $TableMapping = @(),
        
        [ValidateSet("NonQuery", "Scalar", "DataRows", "DataSet", "DataTables")]
        [Alias("As")]
        $OutputAs = "DataRows",

        [switch] $NoSchema,
        [switch] $NoCommandBuilder,
        $InfoMessageVariable = (New-Object Collections.ArrayList),

        $CollectionJoin = [Environment]::NewLine
    )

    begin {
        $infoMessageScript = {
            Set-StrictMode -Version Latest
            $ErrorActionPreference = "Stop"

            # Write-Error has been substituted for Write-Verbose here because otherwise it gets lost
            try {
                $_ | Select-Object -ExpandProperty Errors | ForEach-Object {
                    [void] $InfoMessageVariable.Add($_)                    

                    if ($_.Class -le 10) {
                        "Msg {0}, Level {1}, State {2}, Line {3}$([Environment]::NewLine){4}" -f $_.Number, $_.Class, $_.State, $_.LineNumber, $_.Message | Write-Verbose
                    } else {
                        # Should be Write-Error but it doesn't seem to trigger properly (after -FireInfoMessageEventOnUserErrors) and so it would otherwise up getting lost
                        "Msg {0}, Level {1}, State {2}, Line {3}$([Environment]::NewLine){4}" -f $_.Number, $_.Class, $_.State, $_.LineNumber, $_.Message | Write-Verbose
                    }
                }
            } catch {
                "InfoMessage script error: $_" | Write-Verbose
            }
        }.GetNewClosure()

        # I know this isn't beautiful or awesome and I've forgotten how it works.
        # But it does work most of the time.
        $alterScript = {
            [CmdletBinding()]
            param (
                $DataRows
            )
            Set-StrictMode -Version Latest
            $ErrorActionPreference = "Stop"

            # Process multiple rows one at a time
            foreach ($row in $DataRows) {
                $table = $this
            
                # Get the incoming column names
                if ($row -is [System.Data.DataRow]) {
                    $rowColumnNames = $row.Table.Columns | Select-Object -ExpandProperty ColumnName
                } elseif ($row -is [Hashtable]) {
                    $rowColumnNames = $row.Keys
                } elseif ($row -is [PSObject]) {
                    $newRow = @{}
                    $row.psobject.Properties | ForEach-Object {
                        $newRow.Add($_.Name, $_.Value)
                    }
                    $row = $newRow
                    $rowColumnNames = $row.Keys
                } else {
                    Write-Error "Unknown row type of $($row.GetType().FullName)"
                }

                # Get the primary key column names and values, if any
                $pkName = $table.PrimaryKey | Select-Object -ExpandProperty ColumnName

                $pkValue = New-Object Collections.ArrayList
                foreach ($name in $pkName) {
                    if ($rowColumnNames -contains $name) {
                        [void] $pkValue.Add($row[$name])
                    } else {
                        $pkValue = $null
                        break
                    }
                }

                if ($pkValue -and ($existingRow = $table.Rows.Find($pkValue.ToArray()))) {
                    $newRow = $existingRow
                    # Get properties which are not part of the primary key (as those can't be changed)
                    foreach ($property in ($rowColumnNames | Where-Object { $pkName -notcontains $_ })) {
                        if ($row[$property] -is [System.Collections.ICollection] -and $row[$property] -isnot [byte[]]) {
                            $propertyNull = $row[$property].Count -eq 0
                            $propertyValue = $row[$property] -join $CollectionJoin
                        } else {
                            $propertyNull = $row[$property] -eq $null
                            $propertyValue = $row[$property]
                        }
                        
                        if ($newRow[$property] -ne $propertyValue) {
                            if ($propertyNull) {
                                if ($newRow[$property] -ne [DBNull]::Value) {
                                    $newRow[$property] = [DBNull]::Value
                                }
                            } else {
                                $newRow[$property] = $propertyValue
                            }
                        }
                    }
                } else {
                    $newRow = $table.NewRow()
                    foreach ($property in $rowColumnNames) {
                        if ($row[$property] -is [System.Collections.ICollection] -and $row[$property] -isnot [byte[]]) {
                            $propertyNull = $row[$property].Count -eq 0
                            $propertyValue = $row[$property] -join $CollectionJoin
                        } else {
                            $propertyNull = $row[$property] -eq $null
                            $propertyValue = $row[$property]
                        }
                        
                        if ($propertyNull) {
                            if ($newRow[$property] -ne [DBNull]::Value) {
                                $newRow[$property] = [DBNull]::Value
                            }
                        } else {
                            $newRow[$property] = $propertyValue
                        }
                    }

                    $table.Rows.Add($newRow)
                }
            }

            $sqlDataAdapter.Update($this)
        }
    }

    process {
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
                            Write-Verbose "Couldn't retrieve schema data $($sqlDataAdapter.SelectCommand.CommandText) because $_"
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
                            Write-Verbose "Couldn't build command for $($sqlDataAdapter.SelectCommand.CommandText) because $_"
                        }
                        
                        if ($sqlDataAdapter.InsertCommand -or $sqlDataAdapter.UpdateCommand -or $sqlDataAdapter.DeleteCommand) {
                            # Store a link to the data adapter against the first table along with the alter script
                            Add-Member -InputObject $dataSet.Tables[0] -MemberType ScriptMethod -Name Alter -Value $alterScript.GetNewClosure()
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
