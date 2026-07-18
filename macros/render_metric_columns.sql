{% macro render_metric_columns(metrics, aggregations=('sum', 'avg'), prefix='') -%}
    {%- if not metrics -%}
        {{ exceptions.raise_compiler_error('render_metric_columns requires at least one metric') }}
    {%- endif -%}
    {%- for metric in metrics %}
        {%- set metric_loop = loop -%}
        {%- for aggregation in aggregations %}
            {%- if aggregation not in ['sum', 'avg', 'min', 'max'] -%}
                {{ exceptions.raise_compiler_error('Unsupported aggregation: ' ~ aggregation) }}
            {%- endif %}
    round({{ aggregation }}({{ adapter.quote(metric) }}), 2) as {{ prefix }}{{ aggregation }}_{{ metric }}{% if not (loop.last and metric_loop.last) %},{% endif %}
        {%- endfor %}
    {%- endfor %}
{%- endmacro %}
