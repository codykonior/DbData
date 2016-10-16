<#

.SYNOPSIS
Execute an SqlCommand with a SqlDataAdapter.

.DESCRIPTION
Execute an SqlCommand with a SqlDataAdapter.

.PARAMETER SqlCommand.
An SqlCommand.

.PARAMETER TableMapping
An optional list of table names to use for the result set, in order. By default these are Table, Table1, Table2, etc.

.PARAMETER NoSchema
By default the DataSet attempts to pre-fill itself with the schema information. This can be skipped.

.PARAMETER NoCommandBuild
By default the DataAdapter attempts to pre-fill a CommandBuilder for Insert/Update/Delete commands. This can be skipped.

.PARAMETER DataSet
By default a DataTable is returned. But you can return an entire DataSet.

.INPUTS
Pipe in an SqlCommand.

.OUTPUTS
A PSObject with DataAdapter and DataSet properties.

.EXAMPLE

Create Table dbo.Moo (a Int Identity (1, 1) Primary Key, b Nvarchar(Max))
Import-Module DbData -Force
$table = New-DbConnection -ServerInstance . -Database master | New-DbCommand "Select * From dbo.Moo" | Get-DbData 
$table.Alter(@{ a = 1; b = "A" })
$table.Alter(@{ b = "B" })
$table.Alter(@{ a = 1; b = "C" })
$table.Alter(@{ a = 4; b = "D" })

#>

function Get-DbData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [string[]] $TableMapping = @(),

        [switch] $Rows,
        [switch] $NoSchema,
        [switch] $NoCommandBuilder,

        [switch] $AsDataSet
    )

    Begin {
    }

    Process {
        if ($Rows) {
            $NoSchema = $true
            $NoCommandBuilder = $true
        }

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
                Write-Verbose "No schema information could be retrieved: $_"
            }
        }

        # Get the data
        [void] $sqlDataAdapter.Fill($dataSet)

        # Add Insert/Update/Delete commands
        if (!$NoCommandBuilder) {
            try {
                $commandBuilder = New-Object System.Data.SqlClient.SqlCommandBuilder($SqlDataAdapter)
                [void] $commandBuilder.GetUpdateCommand()
                [void] $commandBuilder.GetInsertCommand()
                [void] $commandBuilder.GetDeleteCommand()
            } catch { 
                Write-Verbose "No CommandBuilder was possible: $_"
            }
        }

        $alterScript = {
            [CmdletBinding()]
            param (
                $Rows
            )
            
            # Process multiple rows one at a time
            foreach ($row in $Rows) {
                # If we are a data set, then use the first table
                if ($this -is [System.Data.DataTable]) {
                    $table = $this
                } else {
                    $table = $this.Tables[0]
                }

                # Get the incoming column names
                if ($row -is [System.Data.DataRow]) {
                    $rowName = $row.Table.Columns | Select -ExpandProperty ColumnName
                } elseif ($row -is [Hashtable]) {
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
                            $newRow[$property] = $row[$property]
                        }
                    }
                } else {
                    $newRow = $table.NewRow()
                    foreach ($property in $rowName) {
                        $newRow[$property] = $row[$property]
                    }

                    $table.Rows.Add($newRow)
                }
            }

            $this.SqlDataAdapter.Update($this)
        }

        if ($Rows) {
            if ($dataSet.Tables.Count -ne 0) {
                $dataSet.Tables[0].Rows
            } else {
                @()
            }
        } elseif ($AsDataSet) {
             # Stores the data adapter we need for later use
            Add-Member -InputObject $dataSet -MemberType NoteProperty -Name SqlDataAdapter -Value $sqlDataAdapter
            # Updates data in the database using the data adapter
            Add-Member -InputObject $dataSet -MemberType ScriptMethod -Name Alter -Value $alterScript -PassThru
        } else {
           if ($dataSet.Tables.Count -ne 0) { # There may be none
                # Stores the data adapter we need for later use
                Add-Member -InputObject $dataSet.Tables[0] -MemberType NoteProperty -Name SqlDataAdapter -Value $sqlDataAdapter
                # Lets you either add a row to the data easily, or, upsert 
                Add-Member -InputObject $dataSet.Tables[0] -MemberType ScriptMethod -Name Alter -Value $alterScript -PassThru
            }
        }
    }

    End {
    }
}
