# Benchmark 20260719T111943.445000Z

**SUCCESS** - `run` completed in **295.922 seconds**.

## Overview

| Metric | Value |
|---|---:|
| Release | `2026-06-17.0` |
| Scale | `germany` |
| Bounding box | `5.866, 47.27, 15.042, 55.099` |
| Models executed | 8 |
| Output Parquet files | 7 |
| Places processed | 4,342,436 |
| Rows across all outputs | 4,573,902 |
| Output size (all files) | 297.5 MiB |
| DuckDB catalog size | 268.0 KiB |

## Model timings

| Model | Status | Seconds |
|---|---|---:|
| `stg_places` | success | 122.737 |
| `int_places` | success | 167.486 |
| `category_summary` | success | 0.294 |
| `confidence_distribution` | success | 0.061 |
| `contactability_summary` | success | 0.144 |
| `density_grid` | success | 0.445 |
| `locality_summary` | success | 0.697 |
| `operating_status_summary` | success | 0.087 |

## Parquet outputs

| File | Rows | Size |
|---|---:|---:|
| `category_summary.parquet` | 1,921 | 51.2 KiB |
| `confidence_distribution.parquet` | 4 | 597.0 B |
| `contactability_summary.parquet` | 261 | 10.1 KiB |
| `density_grid.parquet` | 116,978 | 777.3 KiB |
| `int_places.parquet` | 4,342,436 | 294.9 MiB |
| `locality_summary.parquet` | 112,299 | 1.8 MiB |
| `operating_status_summary.parquet` | 3 | 723.0 B |

## Environment

| Component | Version |
|---|---|
| Platform | Windows-11-10.0.26200-SP0 |
| Python | 3.12.13 |
| DuckDB | 1.5.4 |
| dbt Core | 1.12.0 |
| dbt-DuckDB | 1.10.1 |
| Threads | 1 |

## Detailed artifacts

- **Run Directory:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T111943.445000Z`
- **Console Log:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T111943.445000Z\console.log`
- **Dbt Log:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T111943.445000Z\logs\dbt.log`
- **Run Results:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T111943.445000Z\target\run_results.json`
- **Manifest:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T111943.445000Z\target\manifest.json`
