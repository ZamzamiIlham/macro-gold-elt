from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from scripts.extract_bronze import(
    check_seaweed_conn,
    fetch_and_upload_yahoo,
    fetch_and_upload_jisdor
)
from scripts.load_postgres import(
    load_bronze_to_postgres
)

default_args = {
    "owner": "ilham",
    "depends_on_past": False,
    "retries": 2,
    "retry_delay": timedelta(minutes=3),
    "email_on_failure": False
}

with DAG(
    dag_id = "ingestion_gold_macro",
    default_args = default_args,
    description = "Ingest XAU, DXY and JISDOR to SeawwedFS Bronze Layer",
    schedule_interval = "0 6 * * *",
    start_date = datetime(2026, 11, 16),
    catchup = False,
    tags = ["micro", "gold", "jisdor", "bronze"]
) as dag:

    task_check_s3  = PythonOperator(
        task_id="check_seaweedFS_connection",
        python_callable=check_seaweed_conn,
    )

    task_ingestiion_yahoo = PythonOperator(
        task_id="extract_yahoo_to_bronze",
        python_callable=fetch_and_upload_yahoo
    )

    task_ingestiion_jisdor = PythonOperator(
        task_id="extract_jisdor_to_bronze",
        python_callable=fetch_and_upload_jisdor
    )

    task_load_postgres = PythonOperator(
        task_id='load_bronze_to_stg_postgres',
        python_callable=load_bronze_to_postgres
    )

    task_check_s3 >> [task_ingestiion_yahoo, task_ingestiion_jisdor] >> task_load_postgres