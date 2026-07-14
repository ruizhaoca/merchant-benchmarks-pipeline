-- Expose the forecast as views the dashboard can query directly.
-- Run after 01_create_forecast_model.sql:
--   bq query --project_id=YOUR_GCP_PROJECT_ID --use_legacy_sql=false < ml/02_forecast_views.sql

-- Raw 4-week forecast with 90% prediction intervals.
CREATE OR REPLACE VIEW `analytics.v_category_sales_forecast` AS
SELECT
  product_category,
  DATE(forecast_timestamp) AS week_start,
  forecast_value,
  prediction_interval_lower_bound,
  prediction_interval_upper_bound
FROM ML.FORECAST(
  MODEL `analytics.category_sales_forecast`,
  STRUCT(4 AS horizon, 0.9 AS confidence_level)
);

-- Actuals and forecast in one long table — the shape Looker Studio wants
-- for a single time-series chart with a series-type breakdown.
CREATE OR REPLACE VIEW `analytics.v_sales_actuals_and_forecast` AS
SELECT
  product_category,
  week_start,
  total_sales AS sales,
  CAST(NULL AS FLOAT64) AS lower_bound,
  CAST(NULL AS FLOAT64) AS upper_bound,
  'actual' AS series_type
FROM `analytics.mart_weekly_category_sales`
UNION ALL
SELECT
  product_category,
  week_start,
  forecast_value AS sales,
  prediction_interval_lower_bound AS lower_bound,
  prediction_interval_upper_bound AS upper_bound,
  'forecast' AS series_type
FROM `analytics.v_category_sales_forecast`;
