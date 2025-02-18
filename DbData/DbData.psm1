[CmdletBinding()]
param (
    [bool] $Debugging
)

# Because these are set once in a script scope (modules and functions are all considered in one script scope)
# they will be effective in every function, and won't override or be overridden by changes in parent scopes.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Constrained endpoint compatibility
Set-Alias -Name Exit-PSSession -Value Microsoft.PowerShell.Core\Exit-PSSession
Set-Alias -Name Get-Command -Value Microsoft.PowerShell.Core\Get-Command
Set-Alias -Name Get-FormatData -Value Microsoft.PowerShell.Utility\Get-FormatData
Set-Alias -Name Get-Help -Value Microsoft.PowerShell.Core\Get-Help
Set-Alias -Name Measure-Object -Value Microsoft.PowerShell.Utility\Measure-Object
Set-Alias -Name Out-Default -Value Microsoft.PowerShell.Core\Out-Default
Set-Alias -Name Select-Object -Value Microsoft.PowerShell.Utility\Select-Object

if ($Debugging) {
    foreach ($fileName in (Get-ChildItem $PSScriptRoot "*-*.ps1" -Recurse -Exclude "*.Steps.ps1", "*.Tests.ps1", "*.ps1xml")) {
        try {
            Write-Verbose "Loading function from path '$fileName'."
            . $fileName.FullName
        } catch {
            Write-Error $_
        }
    }
} else {
    if (Test-Path "$PSScriptRoot\Optimize.ps1") {
        $scriptBlock = [System.IO.File]::ReadAllText("$PSScriptRoot\Optimize.ps1")
    } else {
        $scriptBlock = Get-ChildItem $PSScriptRoot "*-*.ps1" -Recurse -Exclude "*.Steps.ps1", "*.Tests.ps1", "*.ps1xml" | ForEach-Object {
            [System.IO.File]::ReadAllText($_.FullName)
        }
    }
    $ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create($scriptBlock), $null, $null)
}

if ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.Location -like "C:\Windows\assembly\*Sql*.dll" }) {
    Write-Warning "SMO DLLs have been loaded from the GAC which may lead to obscure errors"
}
