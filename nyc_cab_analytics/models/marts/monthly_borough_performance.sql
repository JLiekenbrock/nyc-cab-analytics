{% set metrics = var('summary_metrics') %}

select
    date_trunc('month', pickup_date)::date as pickup_month,
    pickup_borough,
    sum(trip_count) as trip_count,
    sum(high_value_trip_count) as high_value_trip_count,
    round({{ safe_divide('sum(high_value_trip_count)', 'sum(trip_count)') }}, 4) as high_value_trip_rate,
    {% for metric in metrics %}
    round(sum(total_{{ metric }}), 2) as total_{{ metric }},
    round({{ safe_divide('sum(total_' ~ metric ~ ')', 'sum(trip_count)') }}, 2) as avg_{{ metric }}{% if not loop.last %},{% endif %}
    {% endfor %}
from {{ ref('int_daily_borough_metrics') }}
group by 1, 2
