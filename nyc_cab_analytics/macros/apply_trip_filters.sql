{% macro apply_trip_filters(
    relation_alias=none,
    start_date=none,
    end_date=none,
    pickup_boroughs=none,
    payment_types=none,
    min_distance_miles=none
) -%}
    {%- set prefix = relation_alias ~ '.' if relation_alias else '' -%}
    {%- set predicates = [] -%}

    {%- if start_date -%}
        {%- do predicates.append(prefix ~ "pickup_at >= cast('" ~ start_date ~ "' as timestamp)") -%}
    {%- endif -%}
    {%- if end_date -%}
        {%- do predicates.append(prefix ~ "pickup_at < cast('" ~ end_date ~ "' as timestamp)") -%}
    {%- endif -%}
    {%- if pickup_boroughs -%}
        {%- set quoted_boroughs = [] -%}
        {%- for borough in pickup_boroughs -%}
            {%- do quoted_boroughs.append("'" ~ borough | replace("'", "''") ~ "'") -%}
        {%- endfor -%}
        {%- do predicates.append(prefix ~ 'pickup_borough in (' ~ quoted_boroughs | join(', ') ~ ')') -%}
    {%- endif -%}
    {%- if payment_types -%}
        {%- set payment_values = [] -%}
        {%- for payment_type in payment_types -%}
            {%- do payment_values.append(payment_type | int | string) -%}
        {%- endfor -%}
        {%- do predicates.append(prefix ~ 'payment_type in (' ~ payment_values | join(', ') ~ ')') -%}
    {%- endif -%}
    {%- if min_distance_miles is not none -%}
        {%- do predicates.append(prefix ~ 'trip_distance_miles >= ' ~ min_distance_miles) -%}
    {%- endif -%}

    {% if predicates %}
    where {{ predicates | join('\n      and ') }}
    {% endif %}
{%- endmacro %}
