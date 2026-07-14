with source as (
    select * from {{ source('olist_raw', 'sellers') }}
)

select
    seller_id,
    seller_zip_code_prefix,
    initcap(seller_city) as seller_city,
    seller_state
from source
