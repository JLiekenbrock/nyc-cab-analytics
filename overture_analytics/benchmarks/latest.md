# Benchmark 20260719T110345.323917Z

**SUCCESS** - `run` completed in **148.679 seconds**.

## Overview

| Metric | Value |
|---|---:|
| Release | `2026-06-17.0` |
| Bounding box | `13.08, 52.34, 13.76, 52.68` |
| Models executed | 8 |
| Output Parquet files | 7 |
| Places processed | 162,163 |
| Rows across all outputs | 165,513 |
| Output size (all files) | 11.0 MiB |
| DuckDB catalog size | 268.0 KiB |

## Model timings

| Model | Status | Seconds |
|---|---|---:|
| `stg_places` | success | 123.017 |
| `int_places` | success | 20.698 |
| `category_summary` | success | 0.082 |
| `confidence_distribution` | success | 0.037 |
| `contactability_summary` | success | 0.047 |
| `density_grid` | success | 0.108 |
| `locality_summary` | success | 0.072 |
| `operating_status_summary` | success | 0.039 |

## Parquet outputs

| File | Rows | Size |
|---|---:|---:|
| `category_summary.parquet` | 1,474 | 36.2 KiB |
| `confidence_distribution.parquet` | 4 | 594.0 B |
| `contactability_summary.parquet` | 251 | 8.7 KiB |
| `density_grid.parquet` | 551 | 8.8 KiB |
| `int_places.parquet` | 162,163 | 10.9 MiB |
| `locality_summary.parquet` | 1,067 | 18.1 KiB |
| `operating_status_summary.parquet` | 3 | 719.0 B |

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

- **Run Directory:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T110345.323917Z`
- **Console Log:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T110345.323917Z\console.log`
- **Dbt Log:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T110345.323917Z\logs\dbt.log`
- **Run Results:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T110345.323917Z\target\run_results.json`
- **Manifest:** `C:\Users\janli\Documents\cabs\overture_analytics\benchmarks\runs\20260719T110345.323917Z\target\manifest.json`
