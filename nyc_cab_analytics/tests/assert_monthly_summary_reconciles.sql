with daily as (
    select date_trunc('month', pickup_date)::date as pickup_month, sum(trip_count) as trip_count
    from {{ ref('daily_trip_summary') }}
    group by 1
),
monthly as (
    select pickup_month, sum(trip_count) as trip_count
    from {{ ref('monthly_borough_performance') }}
    group by 1
)
select *
from daily
full outer join monthly using (pickup_month)
where daily.trip_count is distinct from monthly.trip_count
