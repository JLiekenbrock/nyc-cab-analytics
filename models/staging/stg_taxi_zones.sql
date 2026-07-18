select
    cast(locationid as integer) as location_id,
    trim(borough) as borough,
    trim(zone) as zone,
    trim(service_zone) as service_zone
from {{ source('nyc_tlc', 'taxi_zones') }}
