{# One macro call generates eight aggregate expressions from project vars. #}
select
    pickup_month,
    pickup_borough,
    {{ render_metric_columns(
        var('summary_metrics'),
        aggregations=['sum', 'avg'],
        prefix='all_trips_'
    ) }}
from {{ ref('int_trips_filtered') }}
group by 1, 2
