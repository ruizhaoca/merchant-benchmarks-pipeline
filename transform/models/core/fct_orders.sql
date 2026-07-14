-- Line-item grain: one row per item sold. This grain supports both
-- order-level rollups and merchant-level revenue, since the merchant
-- (seller) is attached to the item, not the order.
with items as (
    select * from {{ ref('stg_order_items') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

reviews as (
    select * from {{ ref('stg_order_reviews') }}
)

select
    concat(i.order_id, '-', cast(i.order_item_id as string)) as order_item_key,
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id as merchant_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_date,
    o.delivery_days,
    r.review_score,
    i.item_price as item_revenue,
    i.freight_value,
    i.item_price + i.freight_value as total_charge
from items i
inner join orders o on i.order_id = o.order_id
left join reviews r on i.order_id = r.order_id
