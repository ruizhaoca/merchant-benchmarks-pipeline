-- Calendar spanning the Olist data window (Sep 2016 - Oct 2018) with margin.
with calendar as (
    select day as date_day
    from unnest(generate_date_array('2016-01-01', '2019-12-31')) as day
)

select
    date_day,
    extract(year from date_day) as year,
    extract(month from date_day) as month,
    format_date('%Y-%m', date_day) as year_month,
    date_trunc(date_day, month) as month_start,
    date_trunc(date_day, week(monday)) as week_start,
    format_date('%A', date_day) as day_name,
    extract(dayofweek from date_day) in (1, 7) as is_weekend
from calendar
