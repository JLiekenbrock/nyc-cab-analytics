{% set grid = var('density_grid_size') %}
select
    floor(longitude / {{ grid }}) * {{ grid }} as cell_xmin,
    floor(latitude / {{ grid }}) * {{ grid }} as cell_ymin,
    count(*) as place_count,
    count(distinct coalesce(basic_category, 'uncategorized')) as category_count,
    round(avg(confidence), 4) as avg_confidence
from {{ ref('int_places') }} group by 1, 2
