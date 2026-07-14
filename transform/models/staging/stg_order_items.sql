with source as (
    select * from {{ source('olist_raw', 'order_items') }}
)

select
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    cast(price as numeric) as item_price,
    cast(freight_value as numeric) as freight_value
from source
