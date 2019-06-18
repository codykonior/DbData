# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- None.

## [2.0.6] - 2019-06-18

### Fixed

- Added aliases for constrained endpoint compatibility.

## [2.0.5] - 2019-05-20

### Fixed

- PSObject types were returning $True BIT fields as NULL. Who knew $true -eq
  [DBNull]::Value? Switched to -is [DBNull].

## [2.0.4] - 2019-05-20

### Fixed

- SMO warning was not working.

## [2.0.3] - 2019-05-20

### Fixed

- Get-DbData won't fail on CREATE PROCEDURE statements anymore. It seems if you
  use AddWithKey on these with .NET it fails. Now it only sets it if it's trying
  to get the schema for -Alter, and even then if that fails it will set it back
  to Add instead.

## [2.0.2] - 2019-05-17

### Fixed

- Removed direct references to the SMO DLL. This prevents old ones from being
  loaded from the GAC and causing issues that are hard to trace.
- Add a warning if SMO DLLs are detected other than those loaded by the
  SqlServer module.

## [2.0.1] - 2019-05-17

### Fixed

- Remove string type from Get-DbSmo SqlCredential that shouldn't have been
  there.
- Re-introduced SqlServer as a dependency. This forces it to load first. I
  found lots of issues where Get-DbSmo can be used without SqlServer being
  loaded and thus picking up incorrect GAC SMO DLLs, which then causes
  later uses of SqlServer functions not fail in mysterious ways.

## [2.0.0] - 2019-04-18

**This has real breaking changes.**

### Changed

- PSCustomObject types are returned by default instead of DataRow.
- Alter functions are no longer added by default.
- Get-DbData parameter CollectionJoin renamed AlterCollectionSeparator.

### Added

- Get-DbData can output as PSCustomObject.
- Get-DbData parameter Alter. This performs the Schema and CommandBuilder
  phases, and adds the Alter function. This can only be used with OutputAs
  DataTable and DataSet.

### Removed

- Get-DbData parameters NoSchema and NoCommandBuilder.

## [1.6.0] - 2019-04-18

### Changed

- Improve module load time.

### Fixed

- Changelog syntax passes VS Code markdown linter.

## [1.5.8] - 2019-04-03

### Added

- `Get-DbSmo` can now accept a `SqlCredential` when used with a server name.

## [1.5.7] - 2018-10-30

### Changes

- Internal structure and documentation. Version bump for PowerShell Gallery.

## [1.5.6] - 2018-10-14

### Fixed

- New-DbCommand CommandTimeout of 0 was timing out. It should not have timed
  out.

## [1.5.5] - 2018-09-10

### Fixed

- Files converted to BOM-less TAB-less UTF-8.

## [1.5.4] - 2018-03-08

### Fixed

- `New-DbConnection` now properly parses input parameters. Previously it wanted
  strings but would silently accept bools and occasionally not set them due to
  the way it checks the value rather than $PSBoundParameters. Now all possible
  input get set accordingly whether "True", "False", $True, or $False.

## [1.5.3] - 2018-03-01

### Fixed

- `Get-DbData` now throws the proper exception object as a parameter to
  Write-Error. Before it was just doing a `Write-Error` and so the exception
  was not properly testable by code like `Use-DbRetry`.

## [1.5.2] - 2018-02-28

### Changed

- `New-DbCommand` no longer accepts a connection string directly. Send it a
SqlConnection object from New-DbConnectionString instead.
- `Get-DbData` now does a Write-Error of exceptions instead of throwing the
raw exception. This allows you to finish faulty pipelines with -ErrorAction
Continue.

## [1.5.1] - 2018-02-27

### Added

- VS Code workspace.
- Extensive AppVeyor testing.
- `New-DbConnection` now accepts pipeline input and a -ConnectionString
  parameter, so you can base one connection string on modifications of
  another.

### Changed

- `Get-DbData` parameters renamed from -OutputAs DataRows/DataTables to the
  singular form DataRow/DataTable.
- `New-DbConnection` now uses the `Add-DbOpen` function on any connections,
  so when it is opened from anywhere in the stack it can use async open by
  default.

## [1.0.8] - 2018-02-20

### Fixed

- Typo in `Use-DbRetry`.

## [1.0.7] - 2018-02-16

### Added

- `New-DbConnection` now allows the use of a SqlCredential (the secure kind,
  as well as the traditional kind), and as a PSCredential too - which it will
  convert.

### Changed

- `Get-DbSmo` now uses Version property to detect if it has successfully
  connected to SMO instead of ComputerNamePhysicalNetBIOS because the
  latter may not appear on some versions of SQL Server. This check is
  required because SMO connections can return but have silently failed.

- `Use-DbRetry` output through `Write-Host` changed back to `Write-Verbose`
  because it was becoming annoying.

## [1.0.6] - 2018-02-05

### Added

- `Get-DbSmo` now accepts pipeline input of the server instance, connection
  string, or SqlConnection object.

## [1.0.4] - 2017-11-08

### Added

- `Add-DbOpen` function replaces a SqlConnection's Open() function with a
  version that does an Async open and wait. This is because I observed
  SQL able to hang a connection and never timeout properly using Open, and
  OpenAsync plus wait resolves that.
- `Get-DbSmo` now does retries and uses `Add-DbOpen`.

### Changed

- `Use-DbRetry` now outputs retries with Write-Host instead of Write-Verbose
  because it was hard to pick up.

- `Use-DbRetry` now does better back-off waits on retries.

### Fixed

- `Get-DbData` .Alter() blocks don't update $null unnecessarily anymore.
- `New-DbConnection` -SqlCredential now applies a Credential to the right
  place in the connection string.
- `Get-DbWmi` loads the correct SMO DLL now.
- `Exit-DbTransaction` Rollback logic improved.
- Fast loading of module outside of ISE done with Invoke-Expression
  ([System.IO.File]::ReadAllText()) reverted as it was unreliable and
  caused a lot of runspace hangs.

## [1.0.4] - 2017-02-27

### Added

- `New-DbConnection` now has an -Open parameter to open the connection before
  returning to the caller. This is to avoid having to constantly make a
  connection, open it, and then pass it to something else.

### Fixed

- `Get-DbSmo` and `Get-DbWmi` now load SMO assemblies in case they aren't
  loaded already.
- Module had a missing dependency on Disposable module, which has been added.
- Dependency on SQLPS module removed by testing for policy evaluation exception
  by type name rather than by type.

## [1.0.3] - 2017-02-22

### Added

- `Get-DbData` can now use -As as an alias for -OutputAs.

### Fixed

- Varbinary now gets written correctly.

## [1.0.2] - 2017-02-18

### Added

- `Get-DbData` now takes a -CollectionJoin parameter. Often you want to pass
  in an array of strings or something to a field and update it, but without
  having to then convert the array of strings to a single string. Now you
  don't have to - just pass in a -CollectionJoin and arrays will be joined
  with the parameter's value before being written to the database.

## [1.0.1] - 2017-02-17

### Added

- `Get-DbSmo` function to get an SMO object but with a complete preload.
- `Get-DbWmi` function to get a ManagedComputer object.
- `New-DbBulkCopy` function to bulk copy a DataSet or DataTable to a database.
- `New-DbConnection` now takes all available ADO.NET connection properties!

### Changed

- `Use-DbRetry` now retries on SQL policy exceptions as these are thrown often
  when evaluating policies concurrently.
- Documentation improvements.

## [1.0.0] - 2016-10-17

### Added

- `Use-DbRetry` function can wrap `Get-DbData` (or other) sections to do
  retries based on SQL failure error codes.
- `New-DbConnection` now accepts a -HostName parameter.
- GPLv3 license.

### Changed

- DataSql module renamed to DbData.
- `New-SqlConnectionString` renamed to `New-DbConnection`.
- `New-SqlCommand` renamed to `New-DbCommand`. -Query and -QueryTimeout
  parameters renamed to -Command and -CommandTimeout. -Parameter input is
  now through a hashtable rather than a Name, Value array.
- `Edit-SqlData` renamed to `Get-DbData.`
- `Enter-SqlTransaction` renamed to `Enter-DbTransaction`.
- `Exit-SqlTransaction` renamed to `Exit-DbTransaction`.

### Removed

- Functions `Add-SqlDataTable`, `Get-SqlType`, and `Write-DataTable` from Chad
  Miller.

## [1.0.0-alpha1] - 2015-09-13

### Added

- `New-SqlCommand` documentation.
- Function `Enter-SqlTransaction` begins a transaction and `Exit-SqlTransaction`
  commits or rolls back.
- `Get-SqlDataSet` and `Get-SqlDataTable` functions to return each of these
  types, by wrapping output from new functions `Edit-SqlData`.
- Functions `Add-SqlDataTable`, `Get-SqlType`, and `Write-DataTable` from Chad
  Miller.

### Changed

- SqlHelper module renamed to DataSql.
- `New-SqlCommand` has an improved error handling for infoMessageVariable.
- `New-SqlCommand` parameter `-QueryTimeout` changed to `-CommandTimeout`.

## [1.0.0-alpha0] - 2015-09-10

### Added

- Initial release of SqlHelper module.
- Function `New-SqlConnectionString` builds a connection string.
- Function `New-SqlCommand` builds a command with proper parameters.
