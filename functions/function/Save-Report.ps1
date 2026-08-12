<#
.SYNOPSIS
    Persists HTML + CSV reports (one per top-level OU) and an optional combined report.
    Opens the output folder when configured.
#>
function Save-Report {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]]$Results,
        [bool]$WhatIf = $true,
        [bool]$Combined = $false,
        [object]$Config = $script:App.Config
    )

    $outFolder = $Config.Report.OutputFolder
    if ([string]::IsNullOrWhiteSpace($outFolder)) {
        $outFolder = Join-Path $script:App.Root 'files\report'
    }
    if (-not (Test-Path $outFolder)) {
        New-Item -ItemType Directory -Path $outFolder -Force | Out-Null
    }

    $stamp  = Get-Date -Format 'yyyy-MM-dd_HH-mm'
    $suffix = if ($WhatIf) { '_WhatIf' } else { '_Live' }
    $written = New-Object System.Collections.Generic.List[string]

    function Get-SafeName([string]$name) {
        $invalid = [IO.Path]::GetInvalidFileNameChars() -join ''
        $re = "[{0}]" -f [regex]::Escape($invalid)
        return (($name -replace $re, '_') -replace '\s+', '_')
    }

    $groups = $Results | Group-Object Ou
    foreach ($grp in $groups) {
        $safe    = Get-SafeName $grp.Name
        $rows    = @($grp.Group)

        $htmlPath = Join-Path $outFolder ("OU_{0}_{1}{2}.html" -f $safe, $stamp, $suffix)
        $csvPath  = Join-Path $outFolder ("OU_{0}_{1}{2}.csv"  -f $safe, $stamp, $suffix)

        (New-HtmlReport -OuName $grp.Name -Results $rows -WhatIf:$WhatIf) | Set-Content -Path $htmlPath -Encoding UTF8
        Write-AppLog ("Report saved: {0}" -f $htmlPath) 'INFO'
        [void]$written.Add($htmlPath)

        New-CsvReport -Results $rows -Path $csvPath | Out-Null
        Write-AppLog ("CSV saved: {0}" -f $csvPath) 'INFO'
        [void]$written.Add($csvPath)
    }

    if ($Combined -and $groups.Count -gt 1) {
        $htmlPath = Join-Path $outFolder ("OU_ALL_{0}{1}.html" -f $stamp, $suffix)
        $csvPath  = Join-Path $outFolder ("OU_ALL_{0}{1}.csv"  -f $stamp, $suffix)
        (New-HtmlReport -OuName 'All OUs (combined)' -Results $Results -WhatIf:$WhatIf) | Set-Content -Path $htmlPath -Encoding UTF8
        New-CsvReport -Results $Results -Path $csvPath | Out-Null
        Write-AppLog ("Combined report saved: {0}" -f $htmlPath) 'INFO'
        [void]$written.Add($htmlPath); [void]$written.Add($csvPath)
    }

    if ($Config.Report.OpenAfterRun -and -not $script:App.DemoMode) {
        try { Start-Process -FilePath $outFolder } catch { }
    }

    return [pscustomobject]@{ Folder = $outFolder; Files = $written.ToArray() }
}
