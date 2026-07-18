{{ config(
    location=env_var('DAILY_SUMMARY_EXPORT_PATH', 'data/exports/daily_trip_summary.parquet'),
    format='parquet'
) }}

select *
from {{ ref('daily_trip_summary') }}
