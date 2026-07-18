{% set filters = var('trip_filters') %}

select *
from {{ ref('int_trips_filtered') }}
where trip_distance_miles < {{ filters.get('min_distance_miles', 0) }}
