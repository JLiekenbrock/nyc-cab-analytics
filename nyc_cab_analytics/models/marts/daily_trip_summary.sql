select
    pickup_date,
    pickup_borough,
    sum(trip_count) as trip_count,
    round(sum(total_trip_distance_miles), 2) as total_distance_miles,
    round({{ safe_divide('sum(total_trip_distance_miles)', 'sum(trip_count)') }}, 2) as avg_distance_miles,
    round(sum(total_fare_amount), 2) as fare_amount,
    round(sum(total_tip_amount), 2) as tip_amount,
    round(sum(total_total_amount), 2) as total_amount
from {{ ref('int_daily_borough_metrics') }}
group by 1, 2
