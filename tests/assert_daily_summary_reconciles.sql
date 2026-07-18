with detailed as (
    select pickup_date, sum(trip_count) as trip_count
    from {{ ref('int_daily_borough_metrics') }}
    group by 1
),
summary as (
    select pickup_date, sum(trip_count) as trip_count
    from {{ ref('daily_trip_summary') }}
    group by 1
)
select
    coalesce(d.pickup_date, s.pickup_date) as pickup_date,
    d.trip_count as detailed_trip_count,
    s.trip_count as summary_trip_count
from detailed d
full outer join summary s using (pickup_date)
where d.trip_count is distinct from s.trip_count
