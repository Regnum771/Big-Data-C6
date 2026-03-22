#!/usr/bin/env python3
"""
generate_dataset.py
───────────────────
Tạo dataset lịch sử 30 ngày giao dịch thương mại điện tử.
Chạy một lần trước khi làm bài tập:
    python scripts/generate_dataset.py

Output: /data/raw/transactions_30days.parquet (~5 triệu bản ghi)
"""

import os
import uuid
import random
import argparse
from datetime import datetime, timedelta

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from tqdm import tqdm

# ─── Cấu hình ────────────────────────────────────────────────────────────────

CATEGORIES   = ["electronics", "fashion", "food", "books", "home", "sports"]
AMOUNT_RANGE = {
    "electronics": (50.0,  5000.0),
    "fashion":     (20.0,  800.0),
    "food":        (5.0,   200.0),
    "books":       (5.0,   150.0),
    "home":        (15.0,  2000.0),
    "sports":      (10.0,  1000.0),
}
NUM_USERS    = 500
NUM_PRODUCTS = 200
FRAUD_RATE   = 0.02          # 2% giao dịch gian lận
OUTPUT_PATH  = "/data/raw/transactions_30days.parquet"

# ─── Logic tạo giao dịch ─────────────────────────────────────────────────────

def make_transaction(ts: datetime) -> dict:
    category = random.choice(CATEGORIES)
    lo, hi   = AMOUNT_RANGE[category]

    # Gian lận: amount thường cao hơn bất thường
    is_fraud = random.random() < FRAUD_RATE
    if is_fraud:
        amount = round(random.uniform(hi * 0.8, hi * 1.5), 2)
    else:
        amount = round(random.uniform(lo, hi), 2)

    return {
        "transaction_id": str(uuid.uuid4()),
        "user_id":        f"user_{random.randint(1, NUM_USERS):03d}",
        "product_id":     f"prod_{random.randint(1, NUM_PRODUCTS):03d}",
        "amount":         amount,
        "category":       category,
        "timestamp":      ts.isoformat(),
        "is_fraud":       is_fraud,
    }

def transactions_per_hour(hour: int) -> int:
    """Mô phỏng traffic theo giờ trong ngày."""
    # Thấp 0-8h, cao điểm 10-12h và 19-22h
    if 0 <= hour < 8:
        return random.randint(50, 150)
    elif 10 <= hour <= 12:
        return random.randint(800, 1200)
    elif 19 <= hour <= 22:
        return random.randint(1000, 1500)
    else:
        return random.randint(300, 600)

# ─── Main ─────────────────────────────────────────────────────────────────────

def generate(n_days: int = 30, batch_size: int = 100_000):
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

    start_date = datetime.now() - timedelta(days=n_days)
    writer     = None
    total      = 0

    print(f"Tạo dataset {n_days} ngày → {OUTPUT_PATH}")
    print(f"Ước tính: ~{n_days * 24 * 700:,} bản ghi\n")

    for day in tqdm(range(n_days), desc="Ngày"):
        buffer = []
        current_day = start_date + timedelta(days=day)

        for hour in range(24):
            n_txn = transactions_per_hour(hour)
            for _ in range(n_txn):
                ts = current_day.replace(hour=hour) + \
                     timedelta(minutes=random.randint(0, 59),
                               seconds=random.randint(0, 59))
                buffer.append(make_transaction(ts))

        # Ghi theo batch để tiết kiệm RAM
        if len(buffer) >= batch_size or day == n_days - 1:
            df    = pd.DataFrame(buffer)
            table = pa.Table.from_pandas(df)

            if writer is None:
                writer = pq.ParquetWriter(OUTPUT_PATH, table.schema,
                                          compression="snappy")
            writer.write_table(table)
            total += len(buffer)
            buffer = []

    if writer:
        writer.close()

    print(f"\n✓ Hoàn thành: {total:,} bản ghi → {OUTPUT_PATH}")
    print(f"  Fraud rate thực tế: "
          f"{pd.read_parquet(OUTPUT_PATH, columns=['is_fraud'])['is_fraud'].mean():.3%}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--days",  type=int, default=30,
                        help="Số ngày lịch sử (mặc định: 30)")
    parser.add_argument("--seed",  type=int, default=42,
                        help="Random seed để kết quả có thể tái tạo")
    args = parser.parse_args()

    random.seed(args.seed)
    generate(n_days=args.days)
