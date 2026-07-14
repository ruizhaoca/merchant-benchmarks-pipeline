-- Weekly sales per product category: the training input for the
-- BigQuery ML ARIMA_PLUS forecast (ml/01_create_forecast_model.sql).
-- The date window trims partial edge weeks and the sparse 2016 ramp-up
-- so the time series is clean enough to model.
with sales as (
    select * from {{ ref('fct_orders') }}
    where order_status = 'delivered'
),

products as (
    select * from {{ ref('dim_product') }}
)

select
    date_trunc(s.order_purchase_date, week(monday)) as week_start,
    p.product_category,
    sum(s.item_revenue) as total_sales,
    count(distinct s.order_id) as orders
from sales s
inner join products p on s.product_id = p.product_id
where s.order_purchase_date between '2017-01-02' and '2018-08-19'
group by 1, 2
