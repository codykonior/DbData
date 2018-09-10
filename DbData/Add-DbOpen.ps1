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

            $result = $null
            $exception = $null

            do {
                try {
                    $result = $task.Wait($this.ConnectionTimeout * 1000)

                    # It can take a little bit to mark completion
                    if (!$task.IsCompleted) {
                        Start-Sleep -Milliseconds 500
                    }
                } catch {
                    $exception = $_
                }

                # Pass on most detailed task exception available
                if ($task.Exception) {
                    if ($task.Exception.psobject.Properties["InnerException"] -and $task.Exception.InnerException) {
                        throw $task.Exception.InnerException
                    } else {
                        throw $task.Exception
                    }
                } elseif ($exception) {
                    throw $exception
                }
            } until ($result -or $exception)
        }
    }

    end {
    }
}
