<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER ServerInstance

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Add-DbOpen {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        $SqlConnection # Microsoft.Data.SqlClient.SqlConnection
    )

    begin {
    }

    process {
        Add-Member -InputObject $SqlConnection -MemberType ScriptMethod -Name Open -Force -Value {
            # Infinite wait
            if ($this.ConnectionTimeout -le 0) {
                Write-Warning "Object [$($this.GetType().FullName)] connection [$($this.ConnectionString)] method [Open] has an infinite wait"
                $wait = -1
            } else {
                $wait = $this.ConnectionTimeout * 1000
            }
            $task = $this.OpenAsync()

            $result = $null
            try {
                $result = $task.Wait($wait)
            } catch {
            }

            if ($task.Exception) {
                Write-Warning "Object [$($this.GetType().FullName)] connection [$($this.ConnectionString)] method [Open] threw an exception"
                throw $task.Exception
            } elseif (-not $result) {
                throw "Object [$($this.GetType().FullName)] connection [$($this.ConnectionString)] method [Open] timed out"
            }
        }
    }

    end {
    }
}
