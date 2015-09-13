<#  
.SYNOPSIS  
Creates a SQL Server table from a DataTable  
.DESCRIPTION  
Creates a SQL Server table from a DataTable using SMO.  
.EXAMPLE  
$dt = Invoke-Sqlcmd2 -ServerInstance "Z003\R2" -Database pubs "select *  from authors"; Add-SqlTable -ServerInstance "Z003\R2" -Database pubscopy -TableName authors -DataTable $dt  
This example loads a variable dt of type DataTable from a query and creates an empty SQL Server table  
.EXAMPLE  
$dt = Get-Alias | Out-DataTable; Add-SqlTable -ServerInstance "Z003\R2" -Database pubscopy -TableName alias -DataTable $dt  
This example creates a DataTable from the properties of Get-Alias and creates an empty SQL Server table.  
.NOTES  
Add-SqlTable uses SQL Server Management Objects (SMO). SMO is installed with SQL Server Management Studio and is available  
as a separate download: http://www.microsoft.com/downloads/details.aspx?displaylang=en&FamilyID=ceb4346f-657f-4d28-83f5-aae0c5c83d52  
Version History  
v1.0   - Chad Miller - Initial Release  
v1.1   - Chad Miller - Updated documentation 
v1.2   - Chad Miller - Add loading Microsoft.SqlServer.ConnectionInfo 
v1.3   - Chad Miller - Added error handling 
v1.4   - Chad Miller - Add VarCharMax and VarBinaryMax handling 
v1.5   - Chad Miller - Added AsScript switch to output script instead of creating table 
v1.6   - Chad Miller - Updated Get-SqlType types 
#>  
function Add-SqlTable {  
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $ServerInstance,
        [Parameter(Position = 1, Mandatory = $true)]
        [string] $Database,
        [Parameter(Position = 2, Mandatory = $true)]
        [string] $SchemaName = "dbo",
        [Parameter(Position = 3, Mandatory = $true)]
        [string] $TableName,
        [Parameter(Position = 4, Mandatory = $true)]
        [System.Data.DataTable] $DataTable,
        [Parameter(Position = 5, Mandatory = $false)]
        [string] $Username,
        [Parameter(Position = 6, Mandatory = $false)]
        [string] $Password,
        [Parameter(Position = 7, Mandatory = $false)]
        [ValidateRange(0, 8000)]
        [int] $MaxLength = 1000,
        [Parameter(Position = 8, Mandatory = $false)]
        [switch] $AsScript
    )  
  
    try { 
        if ($Username) { 
            $con = New-Object ("Microsoft.SqlServer.Management.Common.ServerConnection") $ServerInstance,$Username,$Password
        } else { 
            $con = New-Object ("Microsoft.SqlServer.Management.Common.ServerConnection") $ServerInstance
        }
      
        $con.Connect()
  
        $server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $con
        $db = $server.Databases[$Database]
        $table = New-Object ("Microsoft.SqlServer.Management.Smo.Table") $db, $TableName, $SchemaName
  
        foreach ($column in $DataTable.Columns) {
            $sqlDbType = [Microsoft.SqlServer.Management.Smo.SqlDataType]"$(Get-SqlType $column.DataType.Name)"
            if ($sqlDbType -eq 'VarBinary' -or $sqlDbType -eq 'VarChar') {
                if ($MaxLength -gt 0) {
                    $dataType = New-Object ("Microsoft.SqlServer.Management.Smo.DataType") $sqlDbType, $MaxLength
                } else {
                    $sqlDbType  = [Microsoft.SqlServer.Management.Smo.SqlDataType]"$(Get-SqlType $column.DataType.Name)Max"
                    $dataType = New-Object ("Microsoft.SqlServer.Management.Smo.DataType") $sqlDbType
                }
            } else {
                $dataType = New-Object ("Microsoft.SqlServer.Management.Smo.DataType") $sqlDbType }
                $col = New-Object ("Microsoft.SqlServer.Management.Smo.Column") $table, $column.ColumnName, $dataType
                $col.Nullable = $column.AllowDBNull
                $table.Columns.Add($col)
            }  
  
            if ($AsScript) {
                $table.Script()
            } else { 
                $table.Create()
            } 
        } catch { 
            $message = $_.Exception.GetBaseException().Message
            Write-Error $message 
        } finally {
            $con.Disconnect()
        }
}