select
    coalesce(category, basic_category, 'uncategorized') as category,
    count(*) as place_count,
    count_if(place_name is not null) as named_place_count,
    round(avg(confidence), 4) as avg_confidence,
    count(distinct coalesce(country, 'Unknown')) as country_count,
    round(100.0 * count_if(has_website or has_phone or has_email) / count(*), 2) as contactable_pct
from {{ ref('int_places') }} group by 1
