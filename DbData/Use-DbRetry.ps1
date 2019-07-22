<#

.SYNOPSIS
Retry SQL operations.

.DESCRIPTION
Retry SQL operations. These are only in limited scenarios:
* SQL Server deadlocks and timeouts.
* SQL Server policy evaluation errors (caused by race conditions).

.PARAMETER ScriptBlock
The script you want to execute. It's best to keep this as short as possible, and don't modify variables outside of the scriptblock's scope as they may not be preserved.

.PARAMETER Seconds
The maximum number of seconds that can elapse for retries. This defaults to 3 minutes.

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
    [CmdletBinding(DefaultParametersetName = "Count")]
    param (
        [Parameter(Mandatory)]
        [scriptblock] $Script,

        $RetryCount,
        $RetrySeconds
    )

    begin {
    }

    process {
        # If we haven't supplied any specific retry schedule, default to 3 retries
        if (-not ($PSBoundParameters["RetryCount"] -or $PSBoundParameters["RetrySeconds"])) {
            $RetryCount = 3
        }

        $useDbRetryCount = 0
        $useDbRetryStartTime = Get-Date
        while ($true) {
            try {
                Set-StrictMode -Version Latest
                $ErrorActionPreference = "Stop"

                . $Script
                break
            } catch {
                $useDbRetryException = $_

                while ($true) {
                    if ($useDbRetryException.GetType().FullName -eq "System.Data.SqlClient.SqlException") {
                        break
                    }

                    if ($useDbRetryException.psobject.Properties["Exception"] -and $null -ne $useDbRetryException.Exception) {
                        $useDbRetryException = $useDbRetryException.Exception
                    } elseif ($useDbRetryException.psobject.Properties["InnerException"] -and $null -ne $useDbRetryException.InnerException) {
                        $useDbRetryException = $useDbRetryException.InnerException
                    } else {
                        break
                    }
                }

                $fields = [ordered] @{
                    Retry     = $useDbRetryCount
                    Exception = $useDbRetryException.GetType().FullName
                }
                if ($fields.Exception -eq "System.Data.SqlClient.SqlException") {
                    $fields.Message = $useDbRetryException.Message
                    $fields."Error Number" = $useDbRetryException.Number
                    $fields."Line Number" = $useDbRetryException.LineNumber
                    $fields.Source = $useDbRetryException.Source
                    $fields.Procedure = $useDbRetryException.Procedure
                }
                $fields = [PSCustomObject] $fields
                $fields.psobject.TypeNames.Insert(0, "Use-DbRetry")
                $fields | Format-Custom | Out-String | Write-Verbose

                $useDbRetryCount++

                if ($null -ne $RetryCount) {
                    if ($useDbRetryCount -gt $RetryCount) {
                        Write-Error -Exception $useDbRetryException
                    }
                }
                if ($null -ne $RetrySeconds) {
                    if (((Get-Date) - $useDbRetryStartTime).TotalSeconds -gt $RetrySeconds) {
                        Write-Error -Exception $useDbRetryException
                    }
                }
                if ($null -eq $RetryCount -and $null -eq $RetrySeconds) {
                    Write-Error -Exception $useDbRetryException
                }

                Start-Sleep -Milliseconds (Get-Random ($useDbRetryCount * 3000)) # Linear random backoff, 3 minutes = ~15 retries
            }
        }
    }

    end {
    }
}
