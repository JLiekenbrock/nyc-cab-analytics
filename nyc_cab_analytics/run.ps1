param(
    [ValidateSet('staging', 'intermediate', 'marts', 'exports', 'models', 'test', 'build', 'benchmark')]
    [string]$Part = 'build',
    [string]$Years = '2025,2026',
    [string]$ProfilesDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$localDbt = Join-Path $PSScriptRoot '.venv\Scripts\dbt.exe'
$parentDbt = Join-Path $PSScriptRoot '..\.venv\Scripts\dbt.exe'
$dbt = if (Test-Path -LiteralPath $localDbt) { $localDbt } elseif (Test-Path -LiteralPath $parentDbt) { $parentDbt } else { throw 'No project or shared root dbt executable was found.' }
$python = [System.IO.Path]::ChangeExtension($dbt, 'exe') -replace 'dbt\.exe$', 'python.exe'


Push-Location $PSScriptRoot
try {
    $parquetRoot = if ($env:PARQUET_OUTPUT_ROOT) {
        $env:PARQUET_OUTPUT_ROOT
    }
    else {
        Join-Path $PSScriptRoot 'data\models'
    }
    New-Item -ItemType Directory -Force -Path $parquetRoot | Out-Null

    switch ($Part) {
        'staging'      { & $dbt run --select 'path:models/staging' --profiles-dir $ProfilesDir }
        'intermediate' { & $dbt run --select '+path:models/intermediate' --profiles-dir $ProfilesDir }
        'marts'        { & $dbt run --select '+path:models/marts' --profiles-dir $ProfilesDir }
        'exports'      { & $dbt run --select '+path:models/exports' --profiles-dir $ProfilesDir }
        'models'       { & $dbt run --profiles-dir $ProfilesDir }
        'test'         { & $dbt test --profiles-dir $ProfilesDir }
        'build'        { & $dbt build --profiles-dir $ProfilesDir }
        'benchmark' {
            $yearArgs = @($Years -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            & $python tools\benchmark.py --years @yearArgs --run
        }
    }
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
