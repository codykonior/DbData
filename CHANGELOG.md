# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
- None.

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
