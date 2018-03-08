# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
- None.

## [1.5.4] - 2018-03-08
### Fixed
- `New-DbCommand` now accepts the Pooling parameter as either a string (True,
  False) or a boolean ($True, $False). If you were using booleans before they
  would be ignored by ConnectionBuilder as invalid input (without any error)
  and not be put into the resulting connection string / connection object.

## [1.5.3] - 2018-02-28
### Modified
- `New-DbCommand` no longer accepts a connection string directly. Send it a
SqlConnection object from New-DbConnectionString instead.
- `Get-DbData` now does a Write-Error of exceptions instead of throwing the
raw exception. This allows you to finish faulty pipelines with -ErrorAction
Continue.

## [1.5.1] - 2018-02-27
### Changed
- `Get-DbSmo` now allows parameter values to be piped in by property name.
