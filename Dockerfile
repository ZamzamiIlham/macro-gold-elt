FROM apache/airflow:2.9.3-python3.11
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
USER airflow

COPY requirements.txt /requirements.txt

# Gunakan constraints resmi agar versi library tidak bentrok dengan inti Airflow
RUN pip install --no-cache-dir \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.9.3/constraints-3.11.txt" \
    -r /requirements.txt