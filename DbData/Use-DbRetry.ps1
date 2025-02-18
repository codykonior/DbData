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
    [CmdletBinding()]
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
        if ($null -eq $PSBoundParameters["RetryCount"] -and $null -eq $PSBoundParameters["RetrySeconds"]) {
            $RetryCount = 3
        }

        $firstTime = (Get-Date).ToUniversalTime()
        $execution = 1

        $records = New-Object System.Collections.Generic.List[System.Object]
        while ($true) {
            $startTime = (Get-Date).ToUniversalTime()
            $exception = $null
            try {
                . $Script
            } catch {
                # Try to get to the deepest exception
                $exception = $_
            }
            if (-not $exception) {
                $result = "Pass"
            } else {
                $result = "Fail"
            }

            $record = [PSCustomObject] @{
                FirstTime = $firstTime | Add-Member -MemberType ScriptMethod -Name ToString -Value { if (-not $args.Count) { $args = "yyyy'-'MM'-'dd HH':'mm':'ss.fff'Z'"; }; $this.psbase.ToString($args); } -PassThru -Force
                StartTime = $startTime.TimeOfDay | Add-Member -MemberType ScriptMethod -Name ToString -Value { if (-not $args.Count) { $args = "hh\:mm\:ss\.fff\Z"; }; $this.psbase.ToString($args); } -PassThru -Force
                EndTime   = (Get-Date).ToUniversalTime().TimeOfDay | Add-Member -MemberType ScriptMethod -Name ToString -Value { if (-not $args.Count) { $args = "hh\:mm\:ss\.fff\Z"; }; $this.psbase.ToString($args); } -PassThru -Force
                Result    = $result
                Exception = $exception
            }
            $record.psobject.TypeNames.Insert(0, "Use-DbRetry")
            $records.Add($record)

            if ($result -eq "Pass") {
                break
            }

            $nextSleep = Get-Random (($execution + 1) * 3000) # Linear random backoff, 3 minutes = ~15 retries
            $loop = $true
            if ($null -ne $RetryCount -and $execution -ge ($RetryCount + 1)) {
                $loop = $false
            }
            if ($null -ne $RetrySeconds -and (((Get-Date).ToUniversalTime() - $firstTime).TotalSeconds + ($nextSleep / 1000)) -ge $RetrySeconds) {
                $loop = $false
            }
            if (-not $loop) {
                break
            }

            Start-Sleep -Milliseconds $nextSleep
            $execution++
        }
        if ($records | Where-Object { $_.Exception }) {
            $records | Format-Table | Out-String | Write-Warning
            foreach ($record in $records) {
                if ($record.Exception) {
                    $record.Exception | Select-Object * | Out-String | Write-Warning
                }
            }
        }
        if ($exception) {
            throw $exception
        }
    }

    end {
    }
}
