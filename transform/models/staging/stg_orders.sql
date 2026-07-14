with source as (
    select * from {{ source('olist_raw', 'orders') }}
)

select
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    date(order_purchase_timestamp) as order_purchase_date,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    date_diff(
        date(order_delivered_customer_date),
        date(order_purchase_timestamp),
        day
    ) as delivery_days
from source
