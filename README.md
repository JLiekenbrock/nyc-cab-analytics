# NYC cab analytics with DuckDB, S3, and dbt

This project reads NYC TLC yellow-taxi Parquet directly into DuckDB through dbt. It defaults to all five complete 2026 months available when the project was created (January through May), using the official anonymous HTTPS endpoint. No raw-data download or AWS account is required.

## Quick start (PowerShell)

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e .
.\.venv\Scripts\dbt.exe build --profiles-dir .
.\.venv\Scripts\dbt.exe show --select daily_trip_summary --limit 20 --profiles-dir .
```

The database is created at `data/nyc_cabs.duckdb`.

## Choose another month or an S3 source

Set the source for the current terminal before running dbt. For example, another month is:

```powershell
$env:TLC_TRIP_DATA_FILES = "['https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2026-03.parquet','https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2026-04.parquet']"
```

NYC TLC also publishes the `s3://nyc-tlc` bucket in `us-east-1`. Its current Parquet objects may require signed requests even though the dataset is public, so select the private target to use the standard AWS credential chain:

```powershell
$env:AWS_PROFILE = 'analytics'
$env:AWS_REGION = 'us-east-1'
$env:DBT_TARGET = 'private'
$env:TLC_TRIP_DATA_FILES = "['s3://my-bucket/trips/year=2026/month=*/data.parquet']"
.\.venv\Scripts\dbt.exe build --profiles-dir .
```

DuckDB pushes selected columns and filters into each Parquet scan, so it does not need to download the complete source files. The resulting local mart covers every configured month.

## Project layout

- `models/sources.yml`: external Parquet and taxi-zone sources
- `models/staging/`: typed, cleaned views
- `models/marts/daily_trip_summary.sql`: example analytics table
- `profiles.yml`: local DuckDB plus HTTP/S3 configuration
