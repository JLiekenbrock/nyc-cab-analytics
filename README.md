# NYC cab analytics with DuckDB, S3, and dbt

This project reads NYC TLC yellow-taxi Parquet directly into DuckDB through dbt. It defaults to 29 monthly files: all of 2024 and 2025 plus January through May 2026, using the official anonymous HTTPS endpoint. No raw-data download or AWS account is required.

## Quick start (PowerShell)

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e .
.\.venv\Scripts\dbt.exe build --profiles-dir .
.\.venv\Scripts\dbt.exe show --select daily_trip_summary --limit 20 --profiles-dir .
```

The DuckDB catalog is created at `data/nyc_cabs.duckdb`. Persisted intermediate and mart results are written as Parquet under `data/models/`; DuckDB keeps lightweight views over those files for dbt references and interactive SQL.

The build also writes these DuckDB query results back to Parquet:

- `data/exports/daily_trip_summary.parquet`
- `data/exports/monthly_borough_performance.parquet`

This makes both directions explicit: DuckDB reads the remote TLC Parquet files, dbt transforms them, persisted models are stored as Parquet, and the DuckDB catalog exposes views over those files.

## Run project parts

The root `run.ps1` script provides named entry points:

```powershell
.\run.ps1 -Part staging
.\run.ps1 -Part intermediate
.\run.ps1 -Part marts
.\run.ps1 -Part exports
.\run.ps1 -Part models
.\run.ps1 -Part test
.\run.ps1 -Part build
.\run.ps1 -Part benchmark -Years 2025,2026
```

Intermediate and mart runs include their upstream dependencies. `models` runs models without tests; `build` runs models and tests in dependency order.

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

The export models can write to S3 through the same private target:

```powershell
$env:DBT_TARGET = 'private'
$env:AWS_PROFILE = 'analytics'
$env:AWS_REGION = 'eu-central-1'
$env:DAILY_SUMMARY_EXPORT_PATH = 's3://my-bucket/nyc-cabs/daily_trip_summary.parquet'
$env:MONTHLY_PERFORMANCE_EXPORT_PATH = 's3://my-bucket/nyc-cabs/monthly_borough_performance.parquet'

.\.venv\Scripts\dbt.exe build --select path:models/exports --profiles-dir .
```

Writing to S3 requires `s3:PutObject` permission for the selected prefix. Local exports need no cloud credentials.

DuckDB pushes selected columns and filters into each Parquet scan, so it does not need to download the complete source files. The resulting local mart covers every configured month.

The DuckDB profile disables HTTP keep-alive and uses longer timeouts with retries for the public TLC CDN. These settings avoid transient `HTTP 0 Internal Server Error` failures seen during multi-file scans.

## Data volume benchmark

Inspect the configured remote Parquet volume, the local DuckDB file size, and row counts without rebuilding:

```powershell
.\.venv\Scripts\python.exe tools\benchmark.py
```

Run a timed clean model-processing pass in a temporary directory (the normal database and exports are not replaced):

```powershell
.\.venv\Scripts\python.exe tools\benchmark.py --run
```

The timed command uses `dbt run`, not `dbt build`. Running source tests before model materialization causes additional full remote scans and can trigger the public TLC CDN's range-request rate limit. Run `dbt test` separately when validating the resulting project database.

Limit both the source report and clean build to selected years:

```powershell
.\.venv\Scripts\python.exe tools\benchmark.py --years 2025 2026 --run --output benchmarks\latest.json
```

Add `--json` for machine-readable output. Add `--source-metadata` to probe remote object sizes; this is disabled by default because some CDNs reject metadata requests with HTTP 403. The reported source volume is the sum of compressed object sizes and is an upper bound on network transfer, not an exact byte-scan counter. DuckDB can skip Parquet columns and row groups through projection and predicate pushdown. Set `TLC_TRIP_DATA_FILES` as usual to benchmark a different input set.

Persist a report for comparison with later runs:

```powershell
.\.venv\Scripts\python.exe tools\benchmark.py --run --output benchmarks\latest.json
```

Every invocation automatically writes a concise JSON summary to `benchmarks/latest.json`. It includes source volume coverage, database size, relation row counts, and clean-build timing when `--run` is used. Use `--output` only when you want a different path; missing parent directories are created automatically. Failed builds are also persisted with `succeeded: false`.

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

`int_trips_enriched` is materialized as Parquet under `data/models/`. The public source files are scanned once to create it; downstream models and tests then read the local Parquet result without repeatedly hitting the TLC endpoint.

## Query parameters

`int_trips_filtered` and `fare_segment_summary` accept build-time parameters through dbt's `--vars` option. The defaults in `dbt_project.yml` include every trip.

```powershell
$tripVars = @'
{
  trip_filters: {
    start_date: '2026-03-01',
    end_date: '2026-04-01',
    pickup_boroughs: ['Manhattan', 'Queens'],
    payment_types: [1, 2],
    min_distance_miles: 1
  }
}
'@

.\.venv\Scripts\dbt.exe build --select +fare_segment_summary --vars $tripVars --profiles-dir .
```

Fare segments are also parameters. Override them without editing SQL:

```powershell
.\.venv\Scripts\dbt.exe build --select fare_segment_summary --vars "{fare_segments: [{name: local, min_miles: 0, max_miles: 5}, {name: long_haul, min_miles: 5, max_miles: null}]}" --profiles-dir .
```

For an ad-hoc parameterized query that does not create a model, call the `query_trip_summary` macro:

```powershell
.\.venv\Scripts\dbt.exe run-operation query_trip_summary `
  --args "{start_date: '2026-05-01', end_date: '2026-06-01', pickup_boroughs: ['Manhattan'], payment_types: [1], min_distance_miles: 2, limit: 10}" `
  --profiles-dir .
```

The reusable `apply_trip_filters` macro safely quotes borough values and renders only predicates whose parameters are supplied. `fare_segment` turns the configured list of distance boundaries into a SQL `case` expression.

## Jinja-generated SQL

Two marts are focused examples of Jinja generating SQL at compile time:

- `payment_type_pivot` loops through `payment_type_groups` and creates count/revenue columns for every group. `include_payment_revenue: false` removes all generated revenue columns.
- `metric_catalog` calls `render_metric_columns`, which nests metric and aggregation loops to create the select list. The macro raises a compiler error for an empty metric list or unsupported aggregation.

For example, this override changes both the grain and generated pivot columns:

```powershell
$pivotVars = @'
{
  payment_pivot_dimensions: ['pickup_month', 'day_type'],
  include_payment_revenue: false,
  payment_type_groups: [
    {name: card, values: [1]},
    {name: non_card, values: [2, 3, 4, 5, 6]}
  ]
}
'@

.\.venv\Scripts\dbt.exe compile --select payment_type_pivot --vars $pivotVars --profiles-dir .
Get-Content target\compiled\nyc_cab_analytics\models\marts\payment_type_pivot.sql
```

`dbt compile` is a useful way to learn and debug Jinja because it renders templates without executing the resulting query.

## Project layout

- `models/sources.yml`: external Parquet and taxi-zone sources
- `models/staging/`: typed, cleaned views
- `models/intermediate/`: enriched trips and reusable templated aggregates
- `models/marts/`: daily and monthly analytics tables
- `models/exports/`: external models that write query results to Parquet or S3
- `macros/`: reusable SQL and custom generic tests
- `tests/`: cross-model reconciliation tests
- `profiles.yml`: local DuckDB plus HTTP/S3 configuration
