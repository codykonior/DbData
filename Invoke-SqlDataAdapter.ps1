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

.INPUTS
Pipe in an SqlCommand.

.OUTPUTS
A PSObject with DataAdapter and DataSet properties.

.EXAMPLE
Import-Module SqlHelper -Force
$sql = New-SqlConnectionString -ServerInstance .\SQL2014 -Database master | New-SqlCommand "Select * From sys.master_files" | Invoke-SqlDataAdapter -NoCommandBuilder
$sql.DataSet.Tables[0]

#>

function Invoke-SqlDataAdapter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [string[]] $TableMapping = @(),
        [switch] $NoSchema,
        [switch] $NoCommandBuilder
    )

    Begin {
    }

    Process {
        # Basic type
        $sqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($SqlCommand)

        # Name the tables if they were passed in
        $tableIndex = $null
        $Table | %{
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

        # Return object
        New-Object PSObject -Property @{
            DataAdapter = $sqlDataAdapter
            DataSet = $dataSet
        }
    }

    End {
    }
}
