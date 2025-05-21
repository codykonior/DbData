<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER Query

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Split-DbScript {
    [CmdletBinding(DefaultParameterSetName = "Query")]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Query", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Query,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "FileName")]
        [ValidateNotNullOrEmpty()]
        [Alias("FullName")]
        [string] $FileName
    )

    begin {
        $pathToScriptDomLibrary = Join-Path (Get-Module SqlServer -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 -ExpandProperty ModuleBase) "Microsoft.SqlServer.TransactSql.ScriptDom.dll"
        Add-Type -Path $pathToScriptDomLibrary
        $parserVersion = ([version] ([System.Diagnostics.FileVersionInfo]::GetVersionInfo($pathToScriptDomLibrary).FileVersion)).Major
        $parser = New-Object "Microsoft.SqlServer.TransactSql.ScriptDom.TSql$($parserVersion)0Parser"($true)
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq "FullName") {
            $Query = [System.IO.File]::ReadAllText($FullName)
        }
        $stringReader = New-Object System.IO.StringReader($Query)
        try {
            $parserErrors = New-Object System.Collections.Generic.List[Microsoft.SqlServer.TransactSql.ScriptDom.ParseError]
            $parserData = $parser.Parse($stringReader, [ref] $parserErrors)
            if (-not $parserErrors) {
                foreach ($batch in $parserData.Batches) {
                    $Query.Substring($batch.StartOffset, $batch.FragmentLength)
                }
            } else {
                Write-Error "Function [Split-DbScript] detected parsing errors [$($parserErrors.Message)]"
            }
        } finally {
            $stringReader.Dispose()
        }
    }

    end {

    }
}
