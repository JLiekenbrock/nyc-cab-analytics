{% macro fare_segment(distance_column, segments) -%}
case
    {% for segment in segments %}
    when {{ distance_column }} >= {{ segment.min_miles }}
        {% if segment.max_miles is not none %}and {{ distance_column }} < {{ segment.max_miles }}{% endif %}
        then '{{ segment.name | replace("'", "''") }}'
    {% endfor %}
    else 'unclassified'
end
{%- endmacro %}
