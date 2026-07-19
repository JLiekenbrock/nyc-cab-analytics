{% set b = var('bbox') %}
select
    id,
    names.primary as place_name,
    categories.primary as category,
    basic_category,
    operating_status,
    confidence,
    addresses[1].country as country,
    addresses[1].region as region,
    addresses[1].locality as locality,
    len(websites) > 0 as has_website,
    len(phones) > 0 as has_phone,
    len(emails) > 0 as has_email,
    (bbox.xmin + bbox.xmax) / 2 as longitude,
    (bbox.ymin + bbox.ymax) / 2 as latitude,
    version
from {{ source('overture', 'places') }}
where bbox.xmax >= {{ b.xmin }} and bbox.xmin <= {{ b.xmax }}
  and bbox.ymax >= {{ b.ymin }} and bbox.ymin <= {{ b.ymax }}
