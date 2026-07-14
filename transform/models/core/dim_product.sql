with products as (
    select * from {{ ref('stg_products') }}
),

translation as (
    select * from {{ ref('stg_category_translation') }}
)

select
    p.product_id,
    coalesce(
        t.product_category_name_english,
        p.product_category_name,
        'unknown'
    ) as product_category,
    p.product_weight_g,
    p.product_photos_qty
from products p
left join translation t
    on p.product_category_name = t.product_category_name
