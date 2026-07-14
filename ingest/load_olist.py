"""Load the Olist e-commerce CSVs into BigQuery raw tables.

Raw tables preserve the source column names exactly as they appear in the
CSVs (including the original 'lenght' misspellings) — renaming and typing
cleanup happens downstream in dbt staging models, so raw stays a faithful
copy of the source system.

Usage:
    python ingest/load_olist.py --project YOUR_GCP_PROJECT_ID [--data-dir data] [--dataset olist_raw]

Prereqs:
    gcloud auth application-default login
    pip install google-cloud-bigquery
"""

import argparse
import sys
from pathlib import Path

from google.cloud import bigquery

# filename -> (table_name, schema). Zip code prefixes stay STRING to keep
# leading zeros; timestamps in the CSVs are '%Y-%m-%d %H:%M:%S' which the
# CSV loader parses natively.
TABLES = {
    "olist_orders_dataset.csv": (
        "orders",
        [
            ("order_id", "STRING"),
            ("customer_id", "STRING"),
            ("order_status", "STRING"),
            ("order_purchase_timestamp", "TIMESTAMP"),
            ("order_approved_at", "TIMESTAMP"),
            ("order_delivered_carrier_date", "TIMESTAMP"),
            ("order_delivered_customer_date", "TIMESTAMP"),
            ("order_estimated_delivery_date", "TIMESTAMP"),
        ],
    ),
    "olist_order_items_dataset.csv": (
        "order_items",
        [
            ("order_id", "STRING"),
            ("order_item_id", "INT64"),
            ("product_id", "STRING"),
            ("seller_id", "STRING"),
            ("shipping_limit_date", "TIMESTAMP"),
            ("price", "NUMERIC"),
            ("freight_value", "NUMERIC"),
        ],
    ),
    "olist_order_payments_dataset.csv": (
        "order_payments",
        [
            ("order_id", "STRING"),
            ("payment_sequential", "INT64"),
            ("payment_type", "STRING"),
            ("payment_installments", "INT64"),
            ("payment_value", "NUMERIC"),
        ],
    ),
    "olist_order_reviews_dataset.csv": (
        "order_reviews",
        [
            ("review_id", "STRING"),
            ("order_id", "STRING"),
            ("review_score", "INT64"),
            ("review_comment_title", "STRING"),
            ("review_comment_message", "STRING"),
            ("review_creation_date", "TIMESTAMP"),
            ("review_answer_timestamp", "TIMESTAMP"),
        ],
    ),
    "olist_products_dataset.csv": (
        "products",
        [
            ("product_id", "STRING"),
            ("product_category_name", "STRING"),
            ("product_name_lenght", "INT64"),
            ("product_description_lenght", "INT64"),
            ("product_photos_qty", "INT64"),
            ("product_weight_g", "INT64"),
            ("product_length_cm", "INT64"),
            ("product_height_cm", "INT64"),
            ("product_width_cm", "INT64"),
        ],
    ),
    "olist_sellers_dataset.csv": (
        "sellers",
        [
            ("seller_id", "STRING"),
            ("seller_zip_code_prefix", "STRING"),
            ("seller_city", "STRING"),
            ("seller_state", "STRING"),
        ],
    ),
    "olist_customers_dataset.csv": (
        "customers",
        [
            ("customer_id", "STRING"),
            ("customer_unique_id", "STRING"),
            ("customer_zip_code_prefix", "STRING"),
            ("customer_city", "STRING"),
            ("customer_state", "STRING"),
        ],
    ),
    "olist_geolocation_dataset.csv": (
        "geolocation",
        [
            ("geolocation_zip_code_prefix", "STRING"),
            ("geolocation_lat", "FLOAT64"),
            ("geolocation_lng", "FLOAT64"),
            ("geolocation_city", "STRING"),
            ("geolocation_state", "STRING"),
        ],
    ),
    "product_category_name_translation.csv": (
        "product_category_translation",
        [
            ("product_category_name", "STRING"),
            ("product_category_name_english", "STRING"),
        ],
    ),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True, help="GCP project ID")
    parser.add_argument("--dataset", default="olist_raw", help="Target BigQuery dataset")
    parser.add_argument("--data-dir", default="data", help="Directory containing the Olist CSVs")
    parser.add_argument("--location", default="US", help="BigQuery location")
    args = parser.parse_args()

    data_dir = Path(args.data_dir)
    missing = [f for f in TABLES if not (data_dir / f).exists()]
    if missing:
        print(f"ERROR: missing CSVs in {data_dir.resolve()}:")
        for f in missing:
            print(f"  - {f}")
        print("Download the dataset from https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce")
        return 1

    client = bigquery.Client(project=args.project)
    dataset_ref = bigquery.Dataset(f"{args.project}.{args.dataset}")
    dataset_ref.location = args.location
    client.create_dataset(dataset_ref, exists_ok=True)
    print(f"Dataset {args.project}.{args.dataset} ready.")

    for filename, (table_name, schema) in TABLES.items():
        table_id = f"{args.project}.{args.dataset}.{table_name}"
        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.CSV,
            skip_leading_rows=1,
            schema=[bigquery.SchemaField(name, dtype) for name, dtype in schema],
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,  # idempotent re-runs
            allow_quoted_newlines=True,  # review comments contain newlines
        )
        with open(data_dir / filename, "rb") as fh:
            job = client.load_table_from_file(fh, table_id, job_config=job_config)
        job.result()
        table = client.get_table(table_id)
        print(f"  {table_name:<32} {table.num_rows:>10,} rows")

    print("Done. Next step: cd transform && dbt build")
    return 0


if __name__ == "__main__":
    sys.exit(main())
