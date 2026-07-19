{% macro payment_type_label(column_name) -%}
case {{ column_name }}
    when 1 then 'Credit card'
    when 2 then 'Cash'
    when 3 then 'No charge'
    when 4 then 'Dispute'
    when 5 then 'Unknown'
    when 6 then 'Voided trip'
    else 'Not provided'
end
{%- endmacro %}
