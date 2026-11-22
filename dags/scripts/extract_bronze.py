import json
import logging
import time
import os
import requests
from datetime import datetime, timedelta
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from botocore.exceptions import ClientError
from urllib3.util.retry import Retry
from requests.adapters import HTTPAdapter


log = logging.getLogger(__name__)

SEAWEED_ACCESS_KEY = os.getenv("SEAWEED_ACCESS_KEY")
SEAWEED_SECRET_KEY = os.getenv("SEAWEED_SECRET_KEY")
SEAWEED_BUCKET = "bronze"
SEAWEEDFS_CONN_ID = "seaweedfs_s3"


def check_seaweed_conn():
    s3_hook = S3Hook(aws_conn_id=SEAWEEDFS_CONN_ID)

    if not s3_hook.check_for_bucket(bucket_name=SEAWEED_BUCKET):
        s3_hook.create_bucket(bucket_name=SEAWEED_BUCKET)
        log.info(f"Connection success : bucker {SEAWEED_BUCKET} sucsessfully created")
    else:
        log.info(f"Connection success : bucker {SEAWEED_BUCKET} exists")

def get_bi_session() -> requests.Session:
  """Membuat HTTP Session dengan browser headers lengkap dan auto-retry."""
  session = requests.Session()

  # Konfigurasi retry otomatis jika server BI memutus koneksi tiba-tiba
  retry_strategy = Retry(
      total=5,
      backoff_factor=3,  # Jeda bertingkat: 3s, 6s, 12s, 24s, 48s
      status_forcelist=[429, 500, 502, 503, 504],
      allowed_methods=["GET"],
  )
  adapter = HTTPAdapter(max_retries=retry_strategy)
  session.mount("https://", adapter)
  session.mount("http://", adapter)

  # Header menyerupai browser asli agar lolos WAF bi.go.id
  session.headers.update({
      "User-Agent": (
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
          " (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
      ),
      "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "Accept-Language": "id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7",
      "Connection": "keep-alive",
      "Referer": "https://www.bi.go.id/id/statistik/informasi-kurs/jisdor/Default.aspx",
  })
  return session

def file_exists_in_s3(s3, bucket: str, key: str) -> bool:
  try:
    s3.head_object(Bucket=bucket, Key=key)
    return True
  except ClientError:
    return False

def fetch_and_upload_yahoo(**context):
    s3_hook = S3Hook(aws_conn_id=SEAWEEDFS_CONN_ID)
    s3 = s3_hook.get_conn() 

    execution_date = context["ds"]

    headers = {"User-Agent": "Mozilla/5.0"}

    #cek bucket 10 tahun sudah pernah dibuat atau tidak
    hist_gold_key = "yfinance/gold/historical_10y.json"
    hist_dxy_key = "yfinance/dxy/historical_10y.json"

    if not file_exists_in_s3(s3, SEAWEED_BUCKET, hist_gold_key):
        print("Menjalankan Initial Backfill 10 tahun....")
       
        #ambil json gold
        res_gold_10y = requests.get(
            "https://query1.finance.yahoo.com/v8/finance/chart/GC=F?interval=1d&range=10y",
                headers=headers,
                timeout=30,          
        )
        res_gold_10y.raise_for_status()
        s3.put_object(
            Bucket = SEAWEED_BUCKET, 
            Key = hist_gold_key,
            Body = json.dumps(res_gold_10y.json()),
            ContentType="application/json"
        )

        #ambiil json dxy
        res_dxy_10y = requests.get(
            "https://query1.finance.yahoo.com/v8/finance/chart/DX-Y.NYB?interval=1d&range=10y",
            headers=headers,
            timeout=30,
        )
        res_dxy_10y.raise_for_status()
        s3.put_object(
           Bucket = SEAWEED_BUCKET,
           Key = hist_dxy_key,
           Body = json.dumps(res_dxy_10y.json()),
           ContentType="application/json"
        )
        log.info("Initial Backfill Yahoo Finance success.")

    else:
        log.info(
            f"Running Daily Incremental Yahoo Finance for {execution_date}..."
        )

        res_gold_daily = requests.get(
            "https://query1.finance.yahoo.com/v8/finance/chart/GC=F?interval=1d&range=5d",
            headers=headers,
            timeout=30,          
        )
        res_gold_daily.raise_for_status()
        s3.put_object(
            Bucket = SEAWEED_BUCKET,
            Key = f"yfinance/gold/daily/{execution_date}.json",
            Body = json.dumps(res_gold_daily.json()),
            ContentType="application/json"
        )
        res_dxy_daily = requests.get(
            "https://query1.finance.yahoo.com/v8/finance/chart/DX-Y.NYB?interval=1d&range=5d",
            headers=headers,
            timeout=30,          
        )
        res_dxy_daily.raise_for_status()
        s3.put_object(
            Bucket = SEAWEED_BUCKET,
            Key = f"yfinance/dxy/daily/{execution_date}.json",
            Body = json.dumps(res_dxy_daily.json()),
            ContentType="application/json"
        )
        log.info(f"Sucsessfully upload {execution_date} json")

def fetch_and_upload_jisdor(**context):
    s3_hook = S3Hook(aws_conn_id=SEAWEEDFS_CONN_ID)
    s3 = s3_hook.get_conn()

    logical_date = context["ds"]
    session = get_bi_session()

    url_bi = (
        "https://www.bi.go.id/biwebservice/wskursbi.asmx/getSubKursJisdor3"
    )

    try:
        session.get(
            "https://www.bi.go.id/id/statistik/informasi-kurs/jisdor/Default.aspx",
            timeout=20,
        )
    except Exception as e:
        log.warning(f"Gagal mengambil cookie awal BI, lanjut mencoba API: {e}")

    FIRST_YEAR = 2016
    LAST_YEAR = 2026
    hist_jisdor_key = f"bi/jisdor/historical/{LAST_YEAR}_H2.xml"

    if not file_exists_in_s3(s3, SEAWEED_BUCKET, hist_jisdor_key):
        log.info("Menjalankan Initial Backfill JISDOR (2016 - 2026 per semester)...")
        semesters = [
            ("H1", "01-01", "06-30"),
            ("H2", "07-01", "12-31"),
        ]
        for tahun in range(FIRST_YEAR, LAST_YEAR + 1):
            for sem_label, start_md, end_md in semesters:
                s3_key = f"bi/jisdor/historical/{tahun}_{sem_label}.xml"

                if file_exists_in_s3(s3, SEAWEED_BUCKET, s3_key):
                    log.info(f"File {s3_key} sudah ada, melewati...")
                    continue

                params = {
                    "mts": "USD",
                    "startDate": f"{tahun}-{start_md}",
                    "endDate": f"{tahun}-{end_md}",
                }

                res = session.get(url_bi, params=params, timeout=30)
                res.raise_for_status()

                s3.put_object(
                    Bucket=SEAWEED_BUCKET,
                    Key=s3_key,
                    Body=res.text.encode("utf-8"),
                    ContentType="application/xml",
                )
                log.info(f"Berhasil upload {s3_key}")
                time.sleep(2)
    else:
        log.info(f"Running Daily Incremental JISDOR untuk {logical_date}...")
        end_dt = datetime.strptime(logical_date, "%Y-%m-%d")
        start_dt = end_dt - timedelta(days=5)
        
        params_daily = {
            "mts": "USD",
            "startDate": start_dt.strftime("%Y-%m-%d"),
            "endDate": logical_date,
        }
        # Pakai session.get (bukan requests.get)
        res_daily = session.get(url_bi, params=params_daily, timeout=30)
        res_daily.raise_for_status()

        s3.put_object(
            Bucket=SEAWEED_BUCKET,
            Key=f"bi/jisdor/daily/{logical_date}.xml",
            Body=res_daily.text.encode("utf-8"),
            ContentType="application/xml",
        )
        log.info(f"Successfully upload bi/jisdor/daily/{logical_date}.xml")

