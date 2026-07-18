{% set segments = var('fare_segments') %}
{% set metrics = var('summary_metrics') %}

with segmented as (
    select
        pickup_month,
        pickup_borough,
        {{ fare_segment('trip_distance_miles', segments) }} as fare_segment,
        {% for metric in metrics %}{{ metric }}{% if not loop.last %}, {% endif %}{% endfor %}
    from {{ ref('int_trips_filtered') }}
)
select
    pickup_month,
    pickup_borough,
    fare_segment,
    count(*) as trip_count,
    {% for metric in metrics %}
    round(sum({{ metric }}), 2) as total_{{ metric }},
    round(avg({{ metric }}), 2) as avg_{{ metric }}{% if not loop.last %},{% endif %}
    {% endfor %}
from segmented
group by 1, 2, 3
