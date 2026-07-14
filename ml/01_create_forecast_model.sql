-- Train a weekly sales forecast per product category with BigQuery ML.
-- Run after `dbt build`:
--   bq query --project_id=YOUR_GCP_PROJECT_ID --use_legacy_sql=false < ml/01_create_forecast_model.sql
-- Training is limited to the top 10 categories by revenue: they have
-- dense-enough weekly history to forecast, and it keeps model creation
-- well inside the BigQuery free tier.

CREATE OR REPLACE MODEL `analytics.category_sales_forecast`
OPTIONS (
  model_type = 'ARIMA_PLUS',
  time_series_timestamp_col = 'week_start',
  time_series_data_col = 'total_sales',
  time_series_id_col = 'product_category',
  data_frequency = 'WEEKLY',
  horizon = 4,
  auto_arima = TRUE
) AS
WITH top_categories AS (
  SELECT product_category
  FROM `analytics.mart_weekly_category_sales`
  GROUP BY product_category
  ORDER BY SUM(total_sales) DESC
  LIMIT 10
)
SELECT
  week_start,
  product_category,
  CAST(total_sales AS FLOAT64) AS total_sales
FROM `analytics.mart_weekly_category_sales`
WHERE product_category IN (SELECT product_category FROM top_categories);
