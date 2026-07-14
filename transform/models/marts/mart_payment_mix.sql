-- Monthly payment-method mix: which payment types drive volume — the
-- lens a payments business uses to watch adoption and installment usage.
-- month_start is derived before aggregation so the share-of-month window
-- can partition by a grouped column.
with payments as (
    select
        date_trunc(order_purchase_date, month) as month_start,
        payment_type,
        payment_installments,
        payment_value
    from {{ ref('fct_payments') }}
    where order_status != 'canceled'
)

select
    month_start,
    payment_type,
    count(*) as payment_count,
    sum(payment_value) as payment_volume,
    avg(payment_installments) as avg_installments,
    safe_divide(
        sum(payment_value),
        sum(sum(payment_value)) over (partition by month_start)
    ) as share_of_monthly_volume
from payments
group by 1, 2
