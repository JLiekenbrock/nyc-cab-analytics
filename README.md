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

## Lineage and documentation

Generate and open dbt's local documentation site:

```powershell
.\.venv\Scripts\dbt.exe docs generate --profiles-dir .
.\.venv\Scripts\dbt.exe docs serve --profiles-dir . --port 8080
```

Open `http://localhost:8080` and select the graph icon to explore lineage from the two external TLC sources, through staging and intermediate models, into both marts and the example dashboard exposure.

Useful lineage selectors also work from the command line:

```powershell
# Build a model and every upstream dependency.
.\.venv\Scripts\dbt.exe build --select +monthly_borough_performance --profiles-dir .

# Test a model and every downstream dependent node.
.\.venv\Scripts\dbt.exe test --select int_trips_enriched+ --profiles-dir .
```

## Tests

The project includes standard schema tests, two custom generic tests, and reconciliation tests:

- `accepted_range` validates numeric bounds.
- `unique_combination_of_columns` validates compound model grain.
- Relationships validate taxi-zone references.
- Singular tests reconcile trip counts between intermediate, daily, and monthly layers.

Run all tests with `dbt test --profiles-dir .`, or use `dbt build --profiles-dir .` to build and test in lineage order.

## Templated model design

The SQL is intentionally split into composable files:

1. `stg_*` models normalize the external schemas.
2. `int_trips_enriched` joins pickup and dropoff zones and applies shared business logic.
3. `int_daily_borough_metrics` uses a Jinja loop over `vars.summary_metrics` to generate sums and averages.
4. Daily and monthly marts aggregate the reusable intermediate model.

Change `high_value_fare_threshold` or add a numeric field to `summary_metrics` in `dbt_project.yml` to alter generated SQL without duplicating aggregate expressions. Shared SQL lives in `macros/`, including payment labels and division-by-zero protection.

## Project layout

- `models/sources.yml`: external Parquet and taxi-zone sources
- `models/staging/`: typed, cleaned views
- `models/intermediate/`: enriched trips and reusable templated aggregates
- `models/marts/`: daily and monthly analytics tables
- `macros/`: reusable SQL and custom generic tests
- `tests/`: cross-model reconciliation tests
- `profiles.yml`: local DuckDB plus HTTP/S3 configuration
