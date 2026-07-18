select
    cast(vendorid as integer) as vendor_id,
    cast(tpep_pickup_datetime as timestamp) as pickup_at,
    cast(tpep_dropoff_datetime as timestamp) as dropoff_at,
    cast(passenger_count as integer) as passenger_count,
    cast(trip_distance as double) as trip_distance_miles,
    cast(pulocationid as integer) as pickup_location_id,
    cast(dolocationid as integer) as dropoff_location_id,
    cast(payment_type as integer) as payment_type,
    cast(fare_amount as decimal(12, 2)) as fare_amount,
    cast(tip_amount as decimal(12, 2)) as tip_amount,
    cast(total_amount as decimal(12, 2)) as total_amount,
    cast(cbd_congestion_fee as decimal(12, 2)) as cbd_congestion_fee
from {{ source('nyc_tlc', 'yellow_trips') }}
where
    tpep_pickup_datetime is not null
    and tpep_dropoff_datetime >= tpep_pickup_datetime
    and trip_distance >= 0
