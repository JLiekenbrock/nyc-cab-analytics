with trips as (
    select * from {{ ref('stg_yellow_trips') }}
),
zones as (
    select * from {{ ref('stg_taxi_zones') }}
)
select
    cast(t.pickup_at as date) as pickup_date,
    coalesce(z.borough, 'Unknown') as pickup_borough,
    count(*) as trip_count,
    round(sum(t.trip_distance_miles), 2) as total_distance_miles,
    round(avg(t.trip_distance_miles), 2) as avg_distance_miles,
    round(sum(t.fare_amount), 2) as fare_amount,
    round(sum(t.tip_amount), 2) as tip_amount,
    round(sum(t.total_amount), 2) as total_amount
from trips t
left join zones z on t.pickup_location_id = z.location_id
group by 1, 2
