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
		$SqlConnection # System.Data.SqlClient.SqlConnection
    )

    begin {
    }

    process {
       Add-Member -InputObject $SqlConnection -MemberType ScriptMethod -Name Open -Force -Value {
			$task = $this.OpenAsync()
			$caughtException = $null

            try {
                $result = $task.Wait($this.ConnectionTimeout * 1000)
            } catch {
				$caughtException = $_
			} finally {
				# Tasks can take a little bit to mark completion
				while (!$task.IsCompleted) {
					Start-Sleep -Milliseconds 500
				}

				# Pass on most detailed task exception available
				if ($task.Exception) {
					if ($task.Exception.psobject.Properties["InnerException"] -and $task.Exception.InnerException) {
						throw $task.Exception.InnerException
					} else {
						throw $task.Exception
					}
				}

				# Otherwise pass on any other exception
				if ($caughtException) {
					throw $caughtException
				}
            }
        }
    }

    end {
    }
}
