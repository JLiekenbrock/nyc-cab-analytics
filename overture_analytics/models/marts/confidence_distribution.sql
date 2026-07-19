select
    case when confidence is null then 'unknown'
         when confidence < 0.25 then '0.00-0.24'
         when confidence < 0.50 then '0.25-0.49'
         when confidence < 0.75 then '0.50-0.74'
         else '0.75-1.00' end as confidence_band,
    count(*) as place_count,
    round(100.0 * count(*) / sum(count(*)) over (), 2) as place_pct
from {{ ref('int_places') }} group by 1
