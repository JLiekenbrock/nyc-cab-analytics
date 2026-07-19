select
    coalesce(country, 'Unknown') as country,
    coalesce(region, 'Unknown') as region,
    coalesce(locality, 'Unknown') as locality,
    count(*) as place_count,
    count(distinct coalesce(category, basic_category)) as category_count,
    round(avg(confidence), 4) as avg_confidence
from {{ ref('int_places') }} group by 1, 2, 3
