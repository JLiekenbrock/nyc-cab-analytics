{#
  This model demonstrates compile-time Jinja generation:
  - dimensions come from a project variable
  - payment columns come from a list of dictionaries
  - revenue columns can be enabled or disabled
#}
{% set dimensions = var('payment_pivot_dimensions') %}
{% set payment_groups = var('payment_type_groups') %}
{% set include_revenue = var('include_payment_revenue') %}

select
    {% for dimension in dimensions %}
    {{ adapter.quote(dimension) }},
    {% endfor %}
    count(*) as total_trip_count,
    {{ payment_pivot_columns(payment_groups, include_revenue) }}
from {{ ref('int_trips_filtered') }}
group by
    {% for dimension in dimensions %}
    {{ loop.index }}{% if not loop.last %}, {% endif %}
    {% endfor %}
