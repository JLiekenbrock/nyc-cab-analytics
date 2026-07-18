{% set metrics = var('summary_metrics') %}

select
    pickup_date,
    pickup_borough,
    day_type,
    count(*) as trip_count,
    count_if(is_high_value_fare) as high_value_trip_count,
    {% for metric in metrics %}
    round(sum({{ metric }}), 2) as total_{{ metric }},
    round(avg({{ metric }}), 2) as avg_{{ metric }}{% if not loop.last %},{% endif %}
    {% endfor %}
from {{ ref('int_trips_enriched') }}
group by 1, 2, 3
