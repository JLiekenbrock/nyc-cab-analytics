# DuckDB analytics projects

This repository contains three independent dbt-DuckDB projects:

- [`nyc_cab_analytics/`](nyc_cab_analytics/) — NYC TLC trip analytics over HTTPS/S3 Parquet.
- [`overture_analytics/`](overture_analytics/) — configurable Overture Maps analytics over anonymous S3 GeoParquet.

- [`hybrid_trino_duckdb/`](hybrid_trino_duckdb/) — read-only Trino streams with Delta SCD2 customer/account tables and partition-replaced transaction facts.

Each project has its own README, profile, models, runner, and outputs. A virtual environment at the repository root can be shared by the project runners.
