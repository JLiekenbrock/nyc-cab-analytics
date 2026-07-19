{{ config(
    location=env_var('MONTHLY_PERFORMANCE_EXPORT_PATH', 'data/exports/monthly_borough_performance.parquet'),
    format='parquet'
) }}

select *
from {{ ref('monthly_borough_performance') }}
