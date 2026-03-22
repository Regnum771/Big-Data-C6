# ─────────────────────────────────────────────────────────────────────────────
# Jupyter + PySpark + Kafka client
# Base: jupyter/pyspark-notebook (tích hợp sẵn Spark 3.3 + Python 3.10)
# ─────────────────────────────────────────────────────────────────────────────
FROM jupyter/pyspark-notebook:spark-3.3.2

USER root

# ── Cài thư viện hệ thống ────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    netcat \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Tải Kafka connector JAR cho Spark Structured Streaming ───────────────────
# Bắt buộc để readStream từ Kafka hoạt động trong PySpark
RUN wget -q \
    https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_2.12/3.3.2/spark-sql-kafka-0-10_2.12-3.3.2.jar \
    -O /usr/local/spark/jars/spark-sql-kafka-0-10_2.12-3.3.2.jar \
 && wget -q \
    https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/3.3.2/kafka-clients-3.3.2.jar \
    -O /usr/local/spark/jars/kafka-clients-3.3.2.jar \
 && wget -q \
    https://repo1.maven.org/maven2/org/apache/spark/spark-token-provider-kafka-0-10_2.12/3.3.2/spark-token-provider-kafka-0-10_2.12-3.3.2.jar \
    -O /usr/local/spark/jars/spark-token-provider-kafka-0-10_2.12-3.3.2.jar \
 && wget -q \
    https://repo1.maven.org/maven2/org/apache/commons/commons-pool2/2.11.1/commons-pool2-2.11.1.jar \
    -O /usr/local/spark/jars/commons-pool2-2.11.1.jar

# ── Tạo thư mục dữ liệu ──────────────────────────────────────────────────────
RUN mkdir -p /data/raw /data/output/batch /data/output/anomalies \
             /data/output/fraud_predictions /data/output/model \
    && chown -R ${NB_UID}:${NB_GID} /data

USER ${NB_UID}

# ── Cài thư viện Python ──────────────────────────────────────────────────────
RUN pip install --no-cache-dir \
    # Kafka Python client (Bài 1)
    kafka-python==2.0.2 \
    # Tiện ích dữ liệu
    faker==20.1.0 \
    pandas==2.0.3 \
    pyarrow==13.0.0 \
    # Đánh giá mô hình (Bài 5)
    scikit-learn==1.3.2 \
    # Visualisation trong notebook
    matplotlib==3.7.3 \
    seaborn==0.13.0 \
    # Tiện ích notebook
    tqdm==4.66.1 \
    ipywidgets==8.1.1

# ── Cấu hình Spark mặc định ──────────────────────────────────────────────────
# Các setting này áp dụng cho mọi SparkSession tạo trong notebook
COPY spark-defaults.conf /opt/spark/conf/spark-defaults.conf

# ── Tạo thư mục dữ liệu ──────────────────────────────────────────────────────
RUN mkdir -p /data/raw /data/output/batch /data/output/anomalies \
             /data/output/fraud_predictions /data/output/model

# ── Cài notebook extensions ──────────────────────────────────────────────────
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager 2>/dev/null || true

COPY spark-defaults.conf /usr/local/spark/conf/spark-defaults.conf

WORKDIR /home/jovyan/work

EXPOSE 8888
