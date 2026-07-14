"""Example Airflow DAG showing how this pipeline would be orchestrated in
production on Cloud Composer (GCP's managed Airflow).

NOT deployed for this prototype: a Composer environment costs ~$300+/month,
which is the wrong trade-off for a demo. Locally the same sequence is run
by hand (ingest -> dbt build -> ML refresh); this file documents the
production shape of that sequence.

Production differences worth noting:
- Ingestion would land files in GCS and use GCSToBigQueryOperator (or the
  BigQuery load API) instead of a local script.
- dbt would run via Astronomer Cosmos (renders each dbt model as its own
  Airflow task, with per-model retries and lineage) or a KubernetesPodOperator.
- Failures would page via Slack/PagerDuty callbacks; here we just retry.
"""

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator

GCP_PROJECT = "{{ var.value.gcp_project_id }}"

default_args = {
    "owner": "data-engineering",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="merchant_benchmarks_pipeline",
    description="Ingest Olist raw data, build dbt models, refresh BQML forecast",
    schedule_interval="0 6 * * *",  # daily 06:00 UTC, after upstream exports land
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=default_args,
    tags=["olist", "dbt", "bqml"],
) as dag:

    ingest_raw = BashOperator(
        task_id="ingest_raw_to_bigquery",
        bash_command=(
            "python /home/airflow/gcs/data/ingest/load_olist.py "
            f"--project {GCP_PROJECT} --data-dir /home/airflow/gcs/data/olist"
        ),
    )

    dbt_build = BashOperator(
        task_id="dbt_build",
        bash_command="cd /home/airflow/gcs/dags/transform && dbt build --profiles-dir .",
    )

    refresh_forecast_model = BashOperator(
        task_id="refresh_forecast_model",
        bash_command=(
            f"bq query --project_id={GCP_PROJECT} --use_legacy_sql=false "
            "< /home/airflow/gcs/dags/ml/01_create_forecast_model.sql"
        ),
    )

    refresh_forecast_views = BashOperator(
        task_id="refresh_forecast_views",
        bash_command=(
            f"bq query --project_id={GCP_PROJECT} --use_legacy_sql=false "
            "< /home/airflow/gcs/dags/ml/02_forecast_views.sql"
        ),
    )

    ingest_raw >> dbt_build >> refresh_forecast_model >> refresh_forecast_views
