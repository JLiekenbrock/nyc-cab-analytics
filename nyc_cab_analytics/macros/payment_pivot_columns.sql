{% macro payment_pivot_columns(groups, include_revenue=true) -%}
    {%- if not groups -%}
        {{ exceptions.raise_compiler_error('payment_type_groups must contain at least one group') }}
    {%- endif -%}
    {%- for group in groups %}
        {%- if not group.get('name') or not group.get('values') -%}
            {{ exceptions.raise_compiler_error('Each payment group requires name and values') }}
        {%- endif %}
    count(*) filter (
        where payment_type in ({{ group['values'] | join(', ') }})
    ) as {{ group['name'] }}_trip_count{% if include_revenue %},
    round(sum(total_amount) filter (
        where payment_type in ({{ group['values'] | join(', ') }})
    ), 2) as {{ group['name'] }}_revenue{% endif %}{% if not loop.last %},{% endif %}
    {%- endfor %}
{%- endmacro %}
