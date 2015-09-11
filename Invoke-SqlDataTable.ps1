<#

.SYNOPSIS
Execute an SqlCommand with a SqlDataAdapter but return only the first DataTable.

.DESCRIPTION
Execute an SqlCommand with a SqlDataAdapter but return only the first DataTable.

.PARAMETER SqlCommand.
An SqlCommand.

.PARAMETER NoSchema
By default the DataSet attempts to pre-fill itself with the schema information. This can be skipped.

.INPUTS
Pipe in an SqlCommand.

.OUTPUTS
A DataTable.

.EXAMPLE
Import-Module SqlHelper -Force
$sql = New-SqlConnectionString -ServerInstance .\SQL2014 -Database master | New-SqlCommand "Select * From sys.master_files" | Invoke-SqlDataTable
$sql

#>


function Invoke-SqlDataTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [switch] $NoSchema
    )

    Begin {
    }

    Process {
        $sql = $SqlCommand | Invoke-SqlDataAdapter -NoSchema:$NoSchema -NoCommandBuilder

        # Return first DataTable
        $sql.DataSet.Tables[0]
    }

    End {
    }
}
