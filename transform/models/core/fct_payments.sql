-- One row per payment applied to an order (an order can split across
-- multiple payment methods / installments).
with payments as (
    select * from {{ ref('stg_order_payments') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
)

select
    concat(p.order_id, '-', cast(p.payment_sequential as string)) as payment_key,
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    o.order_purchase_date,
    o.order_status
from payments p
inner join orders o on p.order_id = o.order_id
