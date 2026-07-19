{% macro query_trip_summary(
    start_date=none,
    end_date=none,
    pickup_boroughs=none,
    payment_types=none,
    min_distance_miles=0,
    limit=20
) %}
    {% set sql %}
        select
            pickup_borough,
            payment_type_name,
            count(*) as trip_count,
            round(avg(trip_distance_miles), 2) as avg_distance_miles,
            round(sum(total_amount), 2) as total_revenue
        from {{ ref('int_trips_enriched') }}
        {{ apply_trip_filters(
            start_date=start_date,
            end_date=end_date,
            pickup_boroughs=pickup_boroughs,
            payment_types=payment_types,
            min_distance_miles=min_distance_miles
        ) }}
        group by 1, 2
        order by trip_count desc
        limit {{ limit | int }}
    {% endset %}

    {% if execute %}
        {% set results = run_query(sql) %}
        {{ log(results.print_table(), info=true) }}
    {% endif %}
{% endmacro %}
