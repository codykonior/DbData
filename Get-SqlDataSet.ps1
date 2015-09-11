<#

.SYNOPSIS
Execute an SqlCommand with a SqlDataAdapter but return only the DataSet.

.DESCRIPTION
Execute an SqlCommand with a SqlDataAdapter but return only the DataSet.

.PARAMETER SqlCommand.
An SqlCommand.

.PARAMETER TableMapping
An optional list of table names to use for the result set, in order. By default these are Table, Table1, Table2, etc.

.PARAMETER NoSchema
By default the DataSet attempts to pre-fill itself with the schema information. This can be skipped.

.INPUTS
Pipe in an SqlCommand.

.OUTPUTS
A DataSet.

.EXAMPLE
Import-Module SqlHelper -Force
$sql = New-SqlConnectionString -ServerInstance .\SQL2014 -Database master | New-SqlCommand "Select * From sys.master_files" | Get-SqlDataSet
$sql.Tables[0]

#>

function Get-SqlDataSet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Data.SqlClient.SqlCommand] $SqlCommand,
        [string[]] $TableMapping = @(),
        [switch] $NoSchema
    )

    Begin {
    }

    Process {
        $sql = $SqlCommand | Edit-SqlData -TableMapping $TableMapping -NoSchema:$NoSchema -NoCommandBuilder

        # Return DataSet
        $sql.DataSet
    }

    End {
    }
}
