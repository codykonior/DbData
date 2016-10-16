<#

.SYNOPSIS

Used to retry operations when using SQL objects. It will catch deadlocks
and timeouts, and retry them. It will retry any error which "seems" to
come from SQL, but won't retry other errors.

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Use-DbRetry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock] $Script,
        [int] $MaxRetry = 3,
        [switch] $InfiniteDeadlockRetry = $true
    )

    $retry = 0
    $retryScript = $true

    while ($retryScript -and $retry -le $MaxRetry) {
        try {
            $ErrorActionPreference = "Stop"
            . $Script
            $retryScript = $false
        } catch {
            if (Test-Error -Type System.Data.SqlClient.SqlException) {
                if (Test-Error -Test @{ Number = 1205 }) {
                    Write-Verbose "Caught Deadlock. Retry $retry."
                    if (!$InfiniteDeadlockRetry) {
                        $retry--
                    }

                    Start-Sleep -Milliseconds (Get-Random 5000) # Somewhere up to 5 seconds
                } elseif (Test-Error -Test @{ Number = -2 }) {
                    Write-Verbose "Caught SQL Timeout. Retry $retry."
                    $retry--
                } else {
                    Write-Verbose "Caught unknown SQL Error. $(Resolve-Error -AsString)"
                    $retry--
                }
            } else {
                Write-Verbose "Caught unknown non-SQL Error. $(Resolve-Error -AsString)"
                throw
            }
        } 
    }
}

