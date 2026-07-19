param(
    [ValidateSet('compile', 'staging', 'models', 'test', 'build', 'docs', 'benchmark')]
    [string]$Part = 'build',
    [string]$Release = '2026-06-17.0',
    [string]$Bbox = '13.08,52.34,13.76,52.68'
)

$ErrorActionPreference = 'Stop'
$localDbt = Join-Path $PSScriptRoot '.venv\Scripts\dbt.exe'
$parentDbt = Join-Path $PSScriptRoot '..\.venv\Scripts\dbt.exe'
$dbt = if (Test-Path -LiteralPath $localDbt) { $localDbt } elseif (Test-Path -LiteralPath $parentDbt) { $parentDbt } else { throw 'No project or parent dbt executable was found.' }
$python = [System.IO.Path]::ChangeExtension($dbt, 'exe') -replace 'dbt\.exe$', 'python.exe'

$coordinates = @($Bbox -split ',' | ForEach-Object { [double]$_.Trim() })
if ($coordinates.Count -ne 4) { throw 'Bbox must contain xmin,ymin,xmax,ymax.' }
$vars = @{ bbox = @{ xmin = $coordinates[0]; ymin = $coordinates[1]; xmax = $coordinates[2]; ymax = $coordinates[3] } } | ConvertTo-Json -Compress
$env:OVERTURE_RELEASE = $Release

Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force -Path 'data\models' | Out-Null
    switch ($Part) {
        'compile' { & $dbt compile --vars $vars --profiles-dir . }
        'staging' { & $dbt run --select 'path:models/staging' --vars $vars --profiles-dir . }
        'models'  { & $dbt run --vars $vars --profiles-dir . }
        'test'    { & $dbt test --vars $vars --profiles-dir . }
        'build'   { & $dbt build --vars $vars --profiles-dir . }
        'docs'    { & $dbt docs generate --vars $vars --profiles-dir . }
        'benchmark' { & $python tools\benchmark.py --release $Release --bbox $Bbox }
    }
    exit $LASTEXITCODE
}
finally { Pop-Location }
