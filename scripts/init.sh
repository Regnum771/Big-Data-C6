#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# init.sh — Khởi tạo môi trường sau khi docker compose up
# Chạy: bash scripts/init.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo ""
echo "════════════════════════════════════════════"
echo "   Khởi tạo môi trường Bài tập Chương 6"
echo "════════════════════════════════════════════"
echo ""

# ── 1. Kiểm tra Docker Compose đang chạy ─────────────────────────────────────
log "Kiểm tra các container..."
for svc in zookeeper kafka spark-master jupyter; do
    STATUS=$(docker compose ps --format json 2>/dev/null | \
             python3 -c "import sys,json; [print(c['State']) for c in \
             [json.loads(l) for l in sys.stdin] if c['Service']=='$svc']" 2>/dev/null || echo "")
    if [ "$STATUS" != "running" ]; then
        warn "Container '$svc' chưa chạy. Đang khởi động..."
        docker compose up -d
        sleep 15
        break
    fi
done
log "Tất cả container đang chạy"

# ── 2. Chờ Kafka sẵn sàng ────────────────────────────────────────────────────
log "Chờ Kafka sẵn sàng..."
RETRIES=20
until docker exec kafka kafka-topics.sh \
    --bootstrap-server localhost:9092 --list &>/dev/null; do
    RETRIES=$((RETRIES-1))
    [ $RETRIES -eq 0 ] && err "Kafka không phản hồi sau 100 giây"
    sleep 5
done
log "Kafka sẵn sàng"

# ── 3. Tạo Kafka topics ───────────────────────────────────────────────────────
log "Tạo Kafka topics..."

create_topic() {
    local TOPIC=$1
    local PARTITIONS=${2:-3}
    if docker exec kafka kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --describe --topic "$TOPIC" &>/dev/null; then
        warn "Topic '$TOPIC' đã tồn tại — bỏ qua"
    else
        docker exec kafka kafka-topics.sh \
            --bootstrap-server localhost:9092 \
            --create --topic "$TOPIC" \
            --partitions "$PARTITIONS" \
            --replication-factor 1
        log "Đã tạo topic: $TOPIC (${PARTITIONS} partitions)"
    fi
}

create_topic "transactions"       3
create_topic "fraud-alerts"       1
create_topic "processed-results"  1

# ── 4. Tạo thư mục dữ liệu ───────────────────────────────────────────────────
log "Tạo cấu trúc thư mục /data..."
mkdir -p \
    data/raw \
    data/output/batch/daily_stats \
    data/output/batch/user_stats \
    data/output/anomalies \
    data/output/fraud_predictions \
    data/output/model \
    data/output/checkpoints

# ── 5. Tạo dataset nếu chưa có ────────────────────────────────────────────────
DATASET_PATH="data/raw/transactions_30days.parquet"
if [ -f "$DATASET_PATH" ]; then
    warn "Dataset đã tồn tại tại $DATASET_PATH — bỏ qua"
else
    log "Tạo dataset 30 ngày (khoảng 3–5 phút)..."
    docker exec jupyter python /home/jovyan/scripts/generate_dataset.py --days 30 --seed 42
    log "Dataset đã tạo: $DATASET_PATH"
fi

# ── 6. In thông tin truy cập ──────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo -e "${GREEN}   Môi trường sẵn sàng!${NC}"
echo "════════════════════════════════════════════"
echo ""
echo "  Jupyter Notebook : http://localhost:8888"
echo "  Token            : bigdata2024"
echo "  Spark Master UI  : http://localhost:8080"
echo "  Kafka UI         : http://localhost:8081"
echo ""
echo "  Topics đã tạo:"
echo "    - transactions       (3 partitions) — Bài 1, 2, 4, 5"
echo "    - fraud-alerts       (1 partition)  — Bài 5"
echo "    - processed-results  (1 partition)  — Bài 5"
echo ""
echo "  Dataset: data/raw/transactions_30days.parquet"
echo ""
