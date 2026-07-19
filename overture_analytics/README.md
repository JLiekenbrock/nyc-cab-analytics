# Overture analytics with DuckDB and dbt

This independent project uses dbt with the basic DuckDB adapter to query anonymous, global Overture Maps GeoParquet directly from Amazon S3. DuckDB scans the configured bounding box once into `int_places.parquet`; all meaningful aggregations then run locally and are also persisted as Parquet.

The models filter on the numeric `bbox` metadata and do not require DuckDB's optional spatial extension.

No AWS account or credentials are required.

## Setup

```powershell
cd overture_analytics
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e .
```

## Run

The safe default processes places intersecting the Berlin bounding box:

```powershell
.\run.cmd -Part build
```

Choose any WGS84 bounding box and Overture release:

```powershell
.\run.cmd -Part build `
  -Release '2026-06-17.0' `
  -Bbox '5.866,47.270,15.042,55.099'
```

The bounding-box order is `xmin,ymin,xmax,ymax`. The example above covers Germany. Wider areas process more remote data and produce larger local Parquet files.

Available parts are `compile`, `staging`, `models`, `test`, `build`, and `docs`.

## Detailed benchmark

```powershell
.\run.cmd -Part benchmark `
  -Release '2026-06-17.0' `
  -Scale germany
```

Benchmark scale presets:

- `berlin` — quick city-scale validation
- `germany` — default country-scale benchmark
- `europe` — large explicit opt-in benchmark
- `custom` — uses `-Bbox 'xmin,ymin,xmax,ymax'`

```powershell
.\run.cmd -Part benchmark -Scale custom -Bbox '2.22,48.80,2.47,48.91'
```

Each run creates `benchmarks/runs/<UTC timestamp>/` containing `summary.json`, a human-readable `summary.md`, the complete console log, dbt log, manifest, and `run_results.json`. `benchmarks/latest.json` and `benchmarks/latest.md` always point to the most recent summaries. They cover total wall time, success/failure, every dbt node's timing, source parameters, versions, DuckDB size, and each output Parquet file's rows and bytes.

Render Markdown for an existing JSON result without rerunning dbt:

```powershell
..\.venv\Scripts\python.exe tools\benchmark.py --render-existing benchmarks\latest.json
```

## Outputs

- `data/models/int_places.parquet`
- category and locality summaries
- operating-status distribution
- contactability coverage by category
- confidence-band distribution
- configurable density grid
- `data/overture.duckdb` — lightweight catalog containing views over the Parquet models

The source path is:

```text
s3://overturemaps-us-west-2/release/<release>/theme=places/type=place/*.parquet
```
