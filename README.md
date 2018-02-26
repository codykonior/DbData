![][1]

[![Build status](https://ci.appveyor.com/api/projects/status/oefdf90a75hqsk69?svg=true)](https://ci.appveyor.com/project/codykonior/dbdata)

#### Description

DbData is an awesome replacement for Invoke-Sqlcmd and Invoke-Sqlcmd2.

Invoke-Sqlcmd is littered with bugs, both past and current. DbData fulfills
the promise of Invoke-Sqlcmd with better PowerShell semantics, though without
trying to be a drop-in replacement.

* Safely build connection strings and connections
* Construct commands with really injection-safe parameters
* Execute statements, stored procedures, etc
* Read and alter (insert, update, delete - and upsert!) table data
* Bulk copy tables
* Optionally wrap all of the above with SQL transactions
* Optionally wrap all of the above with retries for deadlocks and timeouts

___Please note: There are [breaking changes](#changes) in DbData 2 from previous versions of DbData.___

#### Requirements
* Requires PowerShell 2.0 or later.
* Requires .NET 3.5 or later installed.
* Options for New-DbConnection vary between .NET Framework versions. Some
were added as recently as 4.6.1.

#### How to use it
Connect to a database and get rows back.

``` powershell
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance master | New-DbCommand "Select * From sys.master_files" | Get-DbData
```

Connect to a database and get multiple result sets into different tables.

``` powershell
$serverInstance = ".\SQL2016"
$dbData = New-DbConnection $serverInstance master | New-DbCommand "Select * From sys.databases; Select * From sys.master_files" | Get-DbData -TableMapping "Databases", "Files" -As DataSet
$dbData.Tables["Databases"]
$dbData.Tables["Files"]
```

Connect to a database, begin a transaction, add data, and then rollback.

``` powershell
$serverInstance = ".\SQL2016"
$dbData = New-DbConnection $serverInstance msdb | New-DbCommand "Select * From dbo.suspect_pages" | Enter-DbTransaction -PassThru | Get-DbData -As DataTables

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

#### Changes

`Get-DbData -OutputAs` changed enumerations from plurals to singular forms:
* DataRows to DataRow
* DataTables to DataTable

[1]: Images/DbData.png
[2]: Images/Test-ComputerPing.gif
