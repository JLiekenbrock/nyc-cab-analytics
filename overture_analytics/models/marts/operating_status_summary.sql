select
    coalesce(operating_status, 'unknown') as operating_status,
    count(*) as place_count,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as place_pct,
    round(avg(confidence), 4) as avg_confidence
from {{ ref('int_places') }} group by 1
