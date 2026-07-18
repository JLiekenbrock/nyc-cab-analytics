with trips as (
    select * from {{ ref('stg_yellow_trips') }}
),
zones as (
    select * from {{ ref('stg_taxi_zones') }}
)
select
    t.*,
    cast(t.pickup_at as date) as pickup_date,
    date_trunc('month', t.pickup_at)::date as pickup_month,
    date_diff('minute', t.pickup_at, t.dropoff_at) as trip_duration_minutes,
    coalesce(pu.borough, 'Unknown') as pickup_borough,
    coalesce(pu.zone, 'Unknown') as pickup_zone,
    coalesce(doz.borough, 'Unknown') as dropoff_borough,
    coalesce(doz.zone, 'Unknown') as dropoff_zone,
    {{ payment_type_label('t.payment_type') }} as payment_type_name,
    {{ safe_divide('t.tip_amount', 't.fare_amount') }} as tip_rate,
    t.fare_amount >= {{ var('high_value_fare_threshold') }} as is_high_value_fare,
    case
        when dayofweek(t.pickup_at) in (0, 6) then 'Weekend'
        else 'Weekday'
    end as day_type
from trips t
left join zones pu on t.pickup_location_id = pu.location_id
left join zones doz on t.dropoff_location_id = doz.location_id
