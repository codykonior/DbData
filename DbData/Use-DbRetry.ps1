<#

.SYNOPSIS
Retry SQL operations.

.DESCRIPTION
Retry SQL operations. These are only in limited scenarios:
* SQL Server deadlocks and timeouts.
* SQL Server policy evaluation errors (caused by race conditions).

.PARAMETER ScriptBlock
The script you want to execute. It's best to keep this as short as possible, and don't modify variables outside of the scriptblock's scope as they may not be preserved.

.PARAMETER Tries
The maximum number of tries to attempt. This defaults to 3, meaning one attempt plus two retries may be made.

.INPUTS
A scriptblock.

.OUTPUTS
Anything output by the scriptblock. But failure information is also written to the Verbose stream.

.EXAMPLE
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance master | New-DbCommand "If Object_Id('dbo.Moo', 'U') Is Not Null Drop Table dbo.Moo; Create Table dbo.Moo (A Int Identity (1, 1) Primary Key, B Nvarchar(Max));" | Get-DbData
$dbData = New-DbConnection $serverInstance master | New-DbCommand "Select * From dbo.Moo" | Enter-DbTransaction -PassThru | Get-DbData -As DataTables
$dbData.Alter(@{ A = 1; B = "B" })
try {
    $dbData2 = New-DbConnection $serverInstance master | New-DbCommand "Select * From dbo.Moo" -CommandTimeout 2 | ForEach-Object {
        Use-DbRetry { Get-DbData $_ } -Verbose
    }
} catch {
    "Exception was caught: $_"
}
Exit-DbTransaction $dbData -Rollback

This drops and recreates a dbo.Moo table (no output), begins a transaction and then upserts a record (returning 1 for 1 record modified).

It then starts a second connection with a short timeout and attempts to select data from the table again. With verbose output this shows a series of timeouts and retry attempts, before throwing an exception which we catch (outputs exception text).

The transaction is then rolled back (no output).

.NOTES
https://docs.microsoft.com/en-us/azure/sql-database/sql-database-connectivity-issues

#>

function Use-DbRetry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock] $Script,
        [int] $Tries = 3
    )

    $try = 1

    while ($try -le $Tries) {
        try {
            $ErrorActionPreference = "Stop"
            . $Script
            break
        } catch {
            if (Test-Error -TypeName "Microsoft.SqlServer.Management.Common.ConnectionFailureException") {
                Write-Verbose "Caught ConnectionFailureException. Try $try."
                $try++
            } elseif (Test-Error @{ Message = "SMO connection silently failed" }) {
                Write-Verbose "Caught silent ConnectionFailureException. Retry $try."
                $try++
            } elseif (Test-Error -TypeName "System.Data.SqlClient.SqlException") {
                if (Test-Error @{ Number = 1205 }) {
                    Write-Verbose "Caught SqlException deadlock. Try $try."
                    $try++
                } elseif (Test-Error @{ Number = -2 }) {
                    Write-Verbose "Caught SqlException timeout. Try $try."
                    $try++
                } else {
                    Write-Error "Caught SqlException unknown error: $_"
                }
            } elseif (Test-Error -TypeName "System.Data.SqlClient.SqlError") {
                if (Test-Error @{ Number = 10054 }) {
                    Write-Verbose "Caught SqlError connection error. Try $try."
                    $try++
                } else {
                    Write-Error "Caught SqlError unknown error: $_"
                }
            } elseif (Test-Error -TypeName "System.Data.DBConcurrencyException") {
                Write-Verbose "Caught ADO.NET concurrency error. Retry $try."
                $try++
            } elseif (Test-Error -TypeName "Microsoft.SqlServer.Management.Dmf.PolicyEvaluationException") {
                Write-Verbose "Caught SQL policy evaluation error. Retry $try."
                $try++
            } else {
                Write-Error "Caught unknown non-SQL error: $_"
                $try++
            }

            if ($try -gt $Tries) {
                throw
            } else {
                Start-Sleep -Milliseconds (Get-Random (1000 * $try)) # Backoff
            }
        }
    }
}
