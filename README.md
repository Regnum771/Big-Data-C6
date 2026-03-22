# Môi trường Docker — Bài tập Chương 6

## Yêu cầu hệ thống

| Thành phần | Tối thiểu |
|---|---|
| RAM | 8 GB (khuyến nghị 12 GB) |
| CPU | 4 cores |
| Dung lượng ổ đĩa | 8 GB trống (khuyễn nghị 10 GB)|
| Docker Desktop | 4.x trở lên |
| Docker Compose | v2 trở lên |

---

## Cấu trúc thư mục

```
docker-setup/
├── docker-compose.yml        ← Định nghĩa toàn bộ services
├── Dockerfile                ← Image Jupyter tùy chỉnh
├── spark-defaults.conf       ← Cấu hình Spark mặc định
├── scripts/
│   ├── init.sh               ← Script khởi tạo (chạy một lần)
│   └── generate_dataset.py   ← Tạo dataset 30 ngày
├── notebooks/                ← Đặt file .ipynb bài tập vào đây. Sử dụng dàn bài 1-5.
└── data/
    ├── raw/                  ← Dataset đầu vào (tự động tạo)
    └── output/               ← Kết quả xử lý của các bài
        ├── batch/
        ├── anomalies/
        ├── fraud_predictions/
        └── model/
```

---

## Hướng dẫn khởi động

### Bước 1 — Build và khởi động containers

```bash
docker compose up -d --build
```

Lần đầu sẽ mất 5–10 phút để tải image và build Dockerfile.jupyter.

### Bước 2 — Khởi tạo môi trường (chạy một lần)

```bash
bash scripts/init.sh
```

Script này sẽ:
- Kiểm tra tất cả containers đang chạy
- Tạo 3 Kafka topics cần thiết
- Tạo cấu trúc thư mục `/data`
- Tạo dataset lịch sử 30 ngày (~3–5 phút)

### Bước 3 — Truy cập Jupyter

Mở trình duyệt tại: **http://localhost:8888**

Token: `bigdata2024`

Đặt file notebook bài tập (`.ipynb`) vào thư mục `notebooks/`.

---

## Địa chỉ các dịch vụ

| Dịch vụ | URL | Ghi chú |
|---|---|---|
| Jupyter Notebook | http://localhost:8888 | Token: `bigdata2024` |
| Spark Master UI | http://localhost:8080 | Theo dõi Spark jobs |
| Kafka UI | http://localhost:8081 | Xem topics, messages |

---

## Kết nối từ notebook

Các biến môi trường đã được thiết lập sẵn trong container Jupyter:

```python
import os

# Kết nối Kafka (dùng trong Bài 1, 2, 5)
KAFKA_SERVERS = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "kafka:9093")

# Kết nối Spark cluster (dùng trong Bài 2, 3, 4, 5)
SPARK_MASTER = os.environ.get("SPARK_MASTER", "spark://spark-master:7077")

# Đường dẫn dữ liệu
DATA_RAW    = os.environ.get("DATA_RAW_PATH",    "/data/raw")
DATA_OUTPUT = os.environ.get("DATA_OUTPUT_PATH", "/data/output")
```

Khởi tạo SparkSession đơn giản (spark-defaults.conf tự động áp dụng):

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("TenBaiTap") \
    .getOrCreate()
```

---

## Lệnh thường dùng

```bash
# Xem logs của một service
docker compose logs -f jupyter
docker compose logs -f kafka

# Restart một service
docker compose restart jupyter

# Mở terminal vào container Jupyter
docker exec -it jupyter bash

# Tắt tất cả (giữ dữ liệu)
docker compose down

# Tắt và xóa toàn bộ dữ liệu
docker compose down -v
rm -rf data/output/*
```

---

## Xử lý lỗi thường gặp

**Jupyter không kết nối được Spark:**
```bash
docker compose restart spark-master spark-worker jupyter
```

**Kafka không nhận message:**
```bash
# Kiểm tra topic đã tồn tại chưa
docker exec kafka kafka-topics.sh --list --bootstrap-server localhost:9092
```

**Hết RAM khi chạy Bài 5:**

Tăng `SPARK_WORKER_MEMORY` trong `docker-compose.yml` lên `3G` nếu máy có đủ RAM, sau đó:
```bash
docker compose up -d spark-worker
```

**Dataset bị hỏng:**
```bash
rm data/raw/transactions_30days.parquet
docker exec jupyter python /home/jovyan/scripts/generate_dataset.py
```
