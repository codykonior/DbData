function Get-SqlType {
	[CmdletBinding()]
	param(
		[string] $TypeName
	)  
  
    switch ($TypeName)   
    {  
        'Boolean' {[Data.SqlDbType]::Bit}  
        'Byte[]' {[Data.SqlDbType]::VarBinary}  
        'Byte'  {[Data.SQLDbType]::VarBinary}  
        'Datetime'  {[Data.SQLDbType]::DateTime}  
        'Decimal' {[Data.SqlDbType]::Decimal}  
        'Double' {[Data.SqlDbType]::Float}  
        'Guid' {[Data.SqlDbType]::UniqueIdentifier}  
        'Int16'  {[Data.SQLDbType]::SmallInt}  
        'Int32'  {[Data.SQLDbType]::Int}  
        'Int64' {[Data.SqlDbType]::BigInt}  
        'UInt16'  {[Data.SQLDbType]::SmallInt}  
        'UInt32'  {[Data.SQLDbType]::Int}  
        'UInt64' {[Data.SqlDbType]::BigInt}  
        'Single' {[Data.SqlDbType]::Decimal} 
        default {[Data.SqlDbType]::VarChar}  
    }
}
