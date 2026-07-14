-- Fails if (order_id, order_item_id) is not unique in stg_order_items.
select
    order_id,
    order_item_id,
    count(*) as n
from {{ ref('stg_order_items') }}
group by 1, 2
having count(*) > 1
