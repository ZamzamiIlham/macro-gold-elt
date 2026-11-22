import json
import logging
import os
import psycopg2
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from psycopg2.extras import execute_values

log = logging.getLogger(__name__)

SEAWEED_ACCESS_KEY = os.getenv("SEAWEED_ACCESS_KEY")
SEAWEED_SECRET_KEY = os.getenv("SEAWEED_SECRET_KEY")
SEAWEED_BUCKET = "bronze"
SEAWEEDFS_CONN_ID = "seaweedfs_s3"
S3_PREFIX = f"s3://{SEAWEED_BUCKET}"

POSTGRES_USER=os.getenv("POSTGRES_USER")
POSTGRES_PASSWORD=os.getenv("POSTGRES_PASSWORD")

DB_CONFIG = {
    "host": "postgres",
    "port": 5432,
    "database": "macro_dw",
    "user": POSTGRES_USER,
    "password": POSTGRES_PASSWORD,
}

def init_postgres_tables(conn):
    ddl_queries = """
        CREATE SCHEMA IF NOT EXISTS raw;

        CREATE TABLE IF NOT EXISTS raw.gold_prices(
            price_date DATE,
            open NUMERIC(18,4),
            high NUMERIC(18,4),
            low NUMERIC(18,4),
            close NUMERIC(18,4),
            volume BIGINT,
            ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS raw.dxy_index(
            price_date DATE,
            open NUMERIC(18,4),
            high NUMERIC(18,4),
            low NUMERIC(18,4),
            close NUMERIC(18,4),
            volume BIGINT,
            ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS raw.jisdor_rates(
            rate_date DATE,
            currency VARCHAR(10),
            jisdor_rate NUMERIC(18,4),
            ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """

    with conn.cursor() as cur:
        cur.execute(ddl_queries)
    conn.commit()

    log.info("Schema raw and table has been created/verificaion")

def parse_yahoo_json(raw_json_str: str)-> list:
    data = json.loads(raw_json_str)
    result = data["chart"]["result"][0]
    timestamps = result.get("timestamp", [])
    quote = result["indicators"]["quote"][0]

    rows = []
    ingested_now = datetime.now(timezone.utc)

    for i, ts in enumerate(timestamps):

        #lewati jika data null
        if quote["close"][i] is None:
            continue
        price_date = datetime.fromtimestamp(ts, timezone.utc).strftime("%Y-%m-%d")
        rows.append((
            price_date,
            quote["open"][i],
            quote["high"][i],
            quote["low"][i],
            quote["close"][i],
            quote["volume"][i],
            ingested_now,
        ))

    return rows

def parse_jisdor_xml(raw_xml_str: str)->list:

    root = ET.fromstring(raw_xml_str)
    rows = []
    ingested_now = datetime.now(timezone.utc)

    # Mencari semua tag <Table> di dalam XML respons BI
    for table in root.findall(".//Table"):
        tgl_node = table.find("tgl_subkursasing")
        nilai_node  = table.find("beli_subkursasing")

        if tgl_node is not None and nilai_node is not None:

            rate_date = tgl_node.text[:10]
            currency = 'USD'
            jisdor_rate = float(nilai_node.text)

            rows.append((
                rate_date,
                currency,
                jisdor_rate,
                ingested_now
            ))

    return rows


def load_bronze_to_postgres(**context):
    execution_date = context["ds"]
    s3_hook = S3Hook(aws_conn_id=SEAWEEDFS_CONN_ID)
    s3 = s3_hook.get_conn()

    conn = psycopg2.connect(**DB_CONFIG)

    try:
        #memastikan semua table tersedia
        init_postgres_tables(conn)

        with conn.cursor() as cur:
            #cek kosong atau tidak
            #untuk menentukan akan memasukan data daily atau initial load 10tahun

            cur.execute("SELECT COUNT(*) FROM raw.gold_prices;")
            is_empty = cur.fetchone()[0] == 0

            if is_empty:
                log.info("Table is null data, load historical + daily data")

                gold_keys = [
                    obj["Key"]
                    for obj in s3.list_objects_v2(
                        Bucket=SEAWEED_BUCKET, Prefix="yfinance/gold/"
                    ).get("Contents", [])
                ]
                dxy_keys = [
                    obj["Key"]
                    for obj in s3.list_objects_v2(
                        Bucket=SEAWEED_BUCKET, Prefix="yfinance/dxy/"
                    ).get("Contents", [])
                ]
                jisdor_keys = [
                    obj["Key"]
                    for obj in s3.list_objects_v2(
                        Bucket=SEAWEED_BUCKET, Prefix="bi/jisdor"
                    ).get("Contents", [])
                ]
            else:
                log.info("Load daily data")
                gold_keys = [f"yfinance/gold/daily/{execution_date}.json"]
                dxy_keys = [f"yfinance/dxy/daily/{execution_date}.json"]
                jisdor_keys = [f"bi/jisdor/daily/{execution_date}.xml"]

            for key in gold_keys:
                obj = s3.get_object(Bucket=SEAWEED_BUCKET, Key=key)
                rows = parse_yahoo_json(obj["Body"].read().decode("utf-8"))

                if rows:
                    execute_values(
                        cur,
                        "INSERT INTO raw.gold_prices (price_date, open, high, low, close,"
                        " volume, ingested_at) VALUES %s",
                        rows,
                    )

            for key in dxy_keys:
                obj = s3.get_object(Bucket=SEAWEED_BUCKET, Key=key)
                rows = parse_yahoo_json(obj["Body"].read().decode("utf-8"))

                if rows:
                    execute_values(
                        cur,
                        "INSERT INTO raw.dxy_index (price_date, open, high, low, close,"
                        " volume, ingested_at) VALUES %s",
                        rows,
                    )
            
            for key in jisdor_keys:
                obj = s3.get_object(Bucket=SEAWEED_BUCKET, Key=key)
                rows = parse_jisdor_xml(obj["Body"].read().decode("utf-8"))

                if rows:
                    execute_values(
                        cur,
                        "INSERT INTO raw.jisdor_rates (rate_date, currency, jisdor_rate,"
                        " ingested_at) VALUES %s",
                        rows,
                    )
        conn.commit()
        log.info("All bonze data sucssesfully load to Postgress on schema raw")
    except Exception as e:
        conn.rollback()
        log.error(f"Failed to load to pOstgress: {e}")
        raise
    finally:
        conn.close()

            