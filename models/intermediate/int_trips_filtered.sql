{% set filters = var('trip_filters') %}

select *
from {{ ref('int_trips_enriched') }}
{{ apply_trip_filters(
    start_date=filters.get('start_date'),
    end_date=filters.get('end_date'),
    pickup_boroughs=filters.get('pickup_boroughs', []),
    payment_types=filters.get('payment_types', []),
    min_distance_miles=filters.get('min_distance_miles')
) }}
