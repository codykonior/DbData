# DbData PowerShell Module by Cody Konior

![][1]

[![Build status](https://ci.appveyor.com/api/projects/status/5yd9egki6r69u864?svg=true)](https://ci.appveyor.com/project/codykonior/dbdata)

Read the [CHANGELOG][3]

## Description

DbData is an awesome replacement for Invoke-Sqlcmd and Invoke-Sqlcmd2.

Invoke-Sqlcmd is littered with bugs, both past and current. DbData fulfills
the promise of Invoke-Sqlcmd with better PowerShell semantics, though without
trying to be a drop-in replacement.

- Safely build connection strings and connections
- Construct commands with really injection-safe parameters
- Execute statements, stored procedures, etc
- Read and alter (insert, update, delete - and upsert!) table data
- Bulk copy tables
- Optionally wrap all of the above with SQL transactions
- Optionally wrap all of the above with retries for deadlocks and timeouts

It also provides quick access to SMO and WMI objects.

## Installation

- `Install-Module DbData`

## Requirements (3.x series)

___Please note: There are [major breaking changes][3] in DbData 3.0 from previous versions of DbData. This build is experimental.___

- Requires PowerShell 7.5 or later.
- Requires the SqlServer module.

Recommendations if you're using Microsoft Entra ID:

```
if (-not $PSDefaultParameterValues.ContainsKey("New-DbConnection:Authentication")) {
    $PSDefaultParameterValues.Add("New-DbConnection:Authentication", "ActiveDirectoryDefault")
}
if (-not $PSDefaultParameterValues.ContainsKey("Get-DbSmo:Raw")) {
    $PSDefaultParameterValues.Add("Get-DbSmo:Raw", $true)
}
```

## Requirements (1.x and 2.x series)

___Please note: There are [minor breaking changes][3] in DbData 1.5 from previous versions of DbData.___

- Requires PowerShell 2.0 or later.
- Requires .NET 3.5 or later installed.
- Options for New-DbConnection vary between .NET Framework versions. Some
were added as recently as 4.6.1.

## Demo

- Making a connection.

  ![DbData makes a connection][21]

- Forming a command and retrieving data.

  ![DbData runs a query][22]

- Creating SMO and WMI objects.

  ![DbData connects over SMO and WMI][23]

## Further Examples

Connect to a database and get rows back.

``` powershell
$serverInstance = "SEC1N1"
New-DbConnection $serverInstance master | New-DbCommand "SELECT * FROM sys.master_files;" | Get-DbData
```

Connect to a database and get multiple result sets into different tables.

``` powershell
$serverInstance = "SEC1N1"
$dbData = New-DbConnection $serverInstance master | New-DbCommand "SELECT * FROM sys.databases; SELECT * FROM sys.master_files;" | Get-DbData -TableMapping "Databases", "Files" -As DataSet
$dbData.Tables["Databases"]
$dbData.Tables["Files"]
```

Connect to a database, begin a transaction, add data, and then rollback.

``` powershell
$serverInstance = "SEC1N1"
$dbData = New-DbConnection $serverInstance msdb | New-DbCommand "SELECT * FROM dbo.suspect_pages;" | Enter-DbTransaction -PassThru | Get-DbData -As DataTables

# Add a record
[void] $dbData.Alter(@{
        database_id = 1
        file_id = 1
        page_id = 1
        event_type = 1
        error_count = 1
        last_update_date = (Get-Date).ToDateTime($null)
    })
Exit-DbTransaction $dbData -Rollback
```

[1]: Images/DbData.ai.svg
[3]: CHANGELOG.md

[21]: Images/dbdata1.gif
[22]: Images/dbdata2.gif
[23]: Images/dbdata3.gif
