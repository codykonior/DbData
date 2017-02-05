<#

.SYNOPSIS
Retry SQL operations that may have timeouts or deadlocks.

.DESCRIPTION
Retry SQL operations that may have timeouts or deadlocks.

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE
Create a dummy table, begin a transaction, and insert data. Then try to delete the data on another connection and show the retries occuring due to the timeout.

Import-Module DbData
$serverInstance = "AG1L"
New-DbConnection $serverInstance | New-DbCommand "If Object_Id('dbo.Moo', 'U') Is Not Null Drop Table dbo.Moo; Create Table dbo.Moo (a Int Identity (1, 1) Primary Key, b Nvarchar(Max))" | Get-DbData
$dbData = New-DbConnection $serverInstance | New-DbCommand "Select * From dbo.Moo" | Enter-DbTransaction -PassThru | Get-DbData
$dbData.Alter(@{ a = 1; b = "A" })

$dbData2 = New-DbConnection $serverInstance | New-DbCommand "Select * From dbo.Moo" -CommandTimeout 2 | %{
    Use-DbRetry { Get-DbData $_ } -Verbose
}

Exit-DbTransaction $dbData -Rollback

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
                    Write-Verbose "Caught SQL deadlock. Retry $retry."
                    if (!$InfiniteDeadlockRetry) {
                        $retry++
                    }
                } elseif (Test-Error -Test @{ Number = -2 }) {
                    Write-Verbose "Caught SQL timeout. Retry $retry."
                    $retry++
                } else {
                    Write-Verbose "Caught unknown SQL error: $(Resolve-Error -AsString)"
                    $retry++
                }
            } elseif (Test-Error -Type Microsoft.SqlServer.Management.Dmf.PolicyEvaluationException) {
                Write-Verbose "Caught SQL policy evaluation error. Retry $retry."
                $retry++
            } else {
                Write-Verbose "Caught unknown non-SQL error: $(Resolve-Error -AsString)"
                throw
            }

            if ($retry -ge $MaxRetry) {
                throw
            }
            Start-Sleep -Milliseconds (Get-Random 5000) # Somewhere up to 5 seconds
        } 
    }
}

