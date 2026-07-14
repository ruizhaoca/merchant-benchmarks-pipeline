-- One row per merchant (Olist seller), enriched with the category they
-- sell most, which drives peer-group benchmarking in the marts.
with sellers as (
    select * from {{ ref('stg_sellers') }}
),

items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('dim_product') }}
),

seller_category_sales as (
    select
        i.seller_id,
        p.product_category,
        sum(i.item_price) as category_revenue,
        row_number() over (
            partition by i.seller_id
            order by sum(i.item_price) desc
        ) as category_rank
    from items i
    inner join products p on i.product_id = p.product_id
    group by 1, 2
),

primary_category as (
    select
        seller_id,
        product_category as primary_category
    from seller_category_sales
    where category_rank = 1
),

seller_activity as (
    select
        seller_id,
        min(date(shipping_limit_date)) as first_active_date,
        count(distinct order_id) as lifetime_orders,
        sum(item_price) as lifetime_gmv
    from items
    group by 1
)

select
    s.seller_id as merchant_id,
    s.seller_city as merchant_city,
    s.seller_state as merchant_state,
    coalesce(pc.primary_category, 'unknown') as primary_category,
    a.first_active_date,
    a.lifetime_orders,
    a.lifetime_gmv
from sellers s
left join primary_category pc on s.seller_id = pc.seller_id
left join seller_activity a on s.seller_id = a.seller_id
