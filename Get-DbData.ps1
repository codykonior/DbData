<#

.SYNOPSIS
Execute an SqlCommand.

.DESCRIPTION
Execute an SqlCommand. Attempts to extract the schema and store it in a table property called SqlDataAdapter. It also adds an Alter() method to each table which optionally can be used with hash tables to do an upsert (on tables with a primary key).

.PARAMETER SqlCommand.
An SqlCommand.

.PARAMETER TableMapping
An optional list of table names to use for the result set, in order. By default these are Table, Table1, Table2, etc.

.PARAMETER Rows
An array of DataRow objects from a DataTable. Note that this cannot be edited as there's no link to their source DataTable.

.PARAMETER Table
By default a DataTable will be returned. This usually enumerates automatically.

.PARAMETER Set
A DataSet can be returned if you want one, usually if you have multiple DataTables.

.PARAMETER NoSchema
For some simple operations, where no editing is required, you might want to skip schema gathering.

.PARAMETER NoCommandBuild
For some simple operations, where no editing is required, you might want to skip command building.

.INPUTS
Pipe in an SqlCommand.

.OUTPUTS
A DataTable, DataSet, or DataRows.

.EXAMPLE
Create a dummy table, insert two rows, edit one of them, then insert a 3rd row. It appears Identity_Insert is handled automatically.

Import-Module DbData
$serverInstance = "AG1L"
New-DbConnection $serverInstance | New-DbCommand "If Object_Id('dbo.Moo', 'U') Is Not Null Drop Table dbo.Moo; Create Table dbo.Moo (a Int Identity (1, 1) Primary Key, b Nvarchar(Max))" | Get-DbData
$dbData = New-DbConnection $serverInstance | New-DbCommand "Select * From dbo.Moo" | Get-DbData
$dbData.Alter(@{ a = 1; b = "A" })
$dbData.Alter(@{ b = "B" })
$dbData.Alter(@{ a = 1; b = "C" })
$dbData.Alter(@{ a = 4; b = "D" })

$dbData | Format-List

<#
a : 1
b : C

a : 2
b : B

a : 4
b : D
#>

#>

function Get-DbData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [string[]] $TableMapping = @(),

        [switch] $Rows,
        [switch] $Table = $true,
        [switch] $Set,
        [switch] $NonQuery,

        [switch] $NoSchema,
        [switch] $NoCommandBuilder,

        $PrintOutput = (New-Object Collections.ArrayList)
    )

    begin {
        $infoMessageScript = {
            Set-StrictMode -Version Latest
            $ErrorActionPreference = "Stop"

            try {
                $_ | Select -ExpandProperty Errors | %{
                    [void] $this.PrintOutput.Add($_)

                    if ($_.Class -le 10) {
                        "Msg {0}, Level {1}, State {2}, Line {3}$([Environment]::NewLine){4}" -f $_.Number, $_.Class, $_.State, $_.LineNumber, $_.Message | Write-Verbose
                    } else {
                        # Should be Write-Error but it doesn't seem to trigger properly (after -FireInfoMessageEventOnUserErrors) and so it would otherwise up getting lost
                        "Msg {0}, Level {1}, State {2}, Line {3}$([Environment]::NewLine){4}" -f $_.Number, $_.Class, $_.State, $_.LineNumber, $_.Message | Write-Verbose
                    }
                }
            } catch { 
                Write-Host $_    
            }
        }
    }

    process {
        $SqlCommand.Connection | Add-Member -MemberType NoteProperty -Name PrintOutput -Value (New-Object Collections.ArrayList)
        $SqlCommand.Connection.add_InfoMessage($infoMessageScript)

        if ($NonQuery) {
            if ($SqlCommand.Connection.State -eq "Open") {
                $SqlCommand.ExecuteNonQuery()
            } else {
                $SqlCommand.Connection.Open()
                $SqlCommand.ExecuteNonQuery()
                $SqlCommand.Connection.Close()
            }
        } else {
            # Basic type
            $sqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCommand)
            $sqlDataAdapter.MissingSchemaAction = "AddWithKey"

            # Name the tables if they were passed in
            $tableIndex = $null
            $TableMapping | %{
                [void] $sqlDataAdapter.TableMappings.Add("Table$tableIndex", $_)
                $tableIndex++
            }

            # Basic type
            $dataSet = New-Object System.Data.DataSet
        
            # Retrieve schema information
            if (!$NoSchema) {
                try {
                    [void] $sqlDataAdapter.FillSchema($dataSet, [System.Data.SchemaType]::Mapped)
                } catch {
                    Write-Verbose "You can't edit this data: $_"
                }
            }

            # Execute / get the data
            [void] $sqlDataAdapter.Fill($dataSet)
        
            # Add Insert/Update/Delete commands
            if (!$NoCommandBuilder) {
                try {
                    $commandBuilder = New-Object System.Data.SqlClient.SqlCommandBuilder($SqlDataAdapter)
                    [void] $commandBuilder.GetUpdateCommand()
                    [void] $commandBuilder.GetInsertCommand()
                    [void] $commandBuilder.GetDeleteCommand()
                } catch { 
                    Write-Verbose "You can't edit this data: $_"
                }
            }

            $alterScript = {
                [CmdletBinding()]
                param (
                    $Rows
                )
            
                # Process multiple rows one at a time
                foreach ($row in $Rows) {
                    $table = $this
                
                    # Get the incoming column names
                    if ($row -is [System.Data.DataRow]) {
                        $rowName = $row.Table.Columns | Select -ExpandProperty ColumnName
                    } elseif ($row -is [Hashtable]) {
                        $rowName = $row.Keys
                    } elseif ($row -is [PSObject]) {
                        $newRow = New-Object Hashtable
                        $row.psobject.Properties | %{
                            $newRow.Add($_.Name, $_.Value)
                        }
                        $row = $newRow
                        $rowName = $row.Keys
                    } else {
                        Write-Error "Unknown row type of $($row.GetType().FullName)"
                    }

                    # Get the primary key names and values, if any
                    $pkName = $table.PrimaryKey | Select -ExpandProperty ColumnName

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
                        foreach ($property in ($rowName | Where { $pkName -notcontains $_ })) {
                            if ($newRow[$property] -ne $row[$property]) {
                                if ($row[$property] -ne $null) {
                                    $newRow[$property] = $row[$property]
                                } else {
                                    $newRow[$property] = [DBNull]::Value
                                }
                            }
                        }
                    } else {
                        $newRow = $table.NewRow()
                        foreach ($property in $rowName) {
                            if ($row[$property] -ne $null) {
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

            $dataSet.Tables | %{
                # Stores the data adapter we need for later use
                Add-Member -InputObject $_ -MemberType NoteProperty -Name SqlDataAdapter -Value $sqlDataAdapter
                # Lets you either add a row to the data easily, or, upsert 
                Add-Member -InputObject $_ -MemberType ScriptMethod -Name Alter -Value $alterScript
            }

            if ($Rows) {
                $dataSet.Tables | %{
                    $_.Rows
                }
            } elseif ($Set) {
                $dataSet
            } else {
                $dataSet.Tables
            }
        }

        [void] $SqlCommand.Connection.remove_InfoMessage($infoMessageScript)
        $SqlCommand.Connection.PrintOutput | %{ [void] $PrintOutput.Add($_) }
        $SqlCommand.Connection.psobject.Members.Remove("PrintOutput")
    }

    end {
    }
}
