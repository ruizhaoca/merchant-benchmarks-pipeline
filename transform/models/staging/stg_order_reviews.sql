with source as (
    select * from {{ source('olist_raw', 'order_reviews') }}
),

-- A few orders have multiple review rows; keep the most recent answer per order.
deduped as (
    select
        *,
        row_number() over (
            partition by order_id
            order by review_answer_timestamp desc
        ) as rn
    from source
)

select
    review_id,
    order_id,
    review_score,
    review_creation_date,
    review_answer_timestamp
from deduped
where rn = 1
