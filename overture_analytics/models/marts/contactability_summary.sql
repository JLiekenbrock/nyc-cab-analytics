select
    coalesce(basic_category, 'uncategorized') as basic_category,
    count(*) as place_count,
    count_if(has_website) as with_website,
    count_if(has_phone) as with_phone,
    count_if(has_email) as with_email,
    round(100.0 * count_if(has_website or has_phone or has_email) / count(*), 2) as contactable_pct
from {{ ref('int_places') }} group by 1
