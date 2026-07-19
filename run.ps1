param(
    [ValidateSet('staging', 'intermediate', 'marts', 'exports', 'models', 'test', 'build', 'benchmark', 'overture')]
    [string]$Part = 'build',
    [string]$Years = '2025,2026',
    [string]$ProfilesDir = $PSScriptRoot,
    [string]$Release = '2026-06-17.0',
    [string]$Theme = 'places',
    [string]$FeatureType = 'place',
    [string]$Bbox,
    [string]$Subtype,
    [string]$FeatureClass,
    [string]$Columns = '*',
    [int]$Limit = 0,
    [string]$Output = 'data\exports\overture_extract.parquet'
)

$ErrorActionPreference = 'Stop'
$dbt = Join-Path $PSScriptRoot '.venv\Scripts\dbt.exe'
$python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'

if (-not (Test-Path -LiteralPath $dbt)) {
    throw "dbt was not found at $dbt. Create the virtual environment first."
}

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
        'overture' {
            $arguments = @(
                'tools\query_overture.py', '--release', $Release,
                '--theme', $Theme, '--type', $FeatureType,
                '--columns', $Columns, '--output', $Output
            )
            if ($Bbox) { $arguments += @('--bbox') + @($Bbox -split ',' | ForEach-Object { $_.Trim() }) }
            if ($Subtype) { $arguments += @('--subtype', $Subtype) }
            if ($FeatureClass) { $arguments += @('--class', $FeatureClass) }
            if ($Limit -gt 0) { $arguments += @('--limit', $Limit.ToString()) }
            & $python @arguments
        }
    }
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
