-- The business centerpiece: each merchant's monthly KPIs benchmarked
-- against the median of peers in the same primary category — a miniature
-- of "how does my store compare to businesses like mine?"
-- Only delivered orders count as realized revenue.
with sales as (
    select * from {{ ref('fct_orders') }}
    where order_status = 'delivered'
),

merchants as (
    select * from {{ ref('dim_merchant') }}
),

merchant_monthly as (
    select
        merchant_id,
        date_trunc(order_purchase_date, month) as month_start,
        sum(item_revenue) as gmv,
        count(distinct order_id) as orders,
        safe_divide(sum(item_revenue), count(distinct order_id)) as avg_order_value,
        avg(review_score) as avg_review_score,
        avg(delivery_days) as avg_delivery_days
    from sales
    group by 1, 2
),

benchmarked as (
    select
        mm.merchant_id,
        m.merchant_city,
        m.merchant_state,
        m.primary_category,
        mm.month_start,
        mm.gmv,
        mm.orders,
        mm.avg_order_value,
        mm.avg_review_score,
        mm.avg_delivery_days,
        -- Peer benchmarks: median across merchants in the same category+month
        percentile_cont(mm.gmv, 0.5) over (
            partition by m.primary_category, mm.month_start
        ) as category_median_gmv,
        percentile_cont(mm.avg_order_value, 0.5) over (
            partition by m.primary_category, mm.month_start
        ) as category_median_aov,
        count(*) over (
            partition by m.primary_category, mm.month_start
        ) as category_peer_count
    from merchant_monthly mm
    inner join merchants m on mm.merchant_id = m.merchant_id
)

select
    *,
    safe_divide(gmv - category_median_gmv, category_median_gmv) as gmv_vs_median_pct,
    safe_divide(avg_order_value - category_median_aov, category_median_aov) as aov_vs_median_pct
from benchmarked
