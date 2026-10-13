#!/bin/bash
# ============================================================
# commands.sh – Bài 4: Custom Network & Named Volume
# Session 10 – DevOps Specialist
# ============================================================
# Script thực hiện toàn bộ quy trình:
#   1. Tạo Custom Bridge Network: app-net
#   2. Tạo Named Volume: db-data
#   3. Khởi chạy Database Container (postgres:15-alpine)
#   4. Khởi chạy Backend Container (hw-backend:v1)
#   5. Kiểm tra DNS resolution và kết nối nội bộ
#   6. Test Data Persistence (xóa cứng DB container và tạo lại)
# ============================================================

set -e  # Dừng script ngay nếu có lỗi

echo "========================================================"
echo " BƯỚC 1: Tạo Custom Bridge Network: app-net"
echo "========================================================"

docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  app-net

echo "[OK] Network 'app-net' đã được tạo."

echo ""
echo "========================================================"
echo " BƯỚC 2: Tạo Named Volume: db-data"
echo "========================================================"

docker volume create db-data

echo "[OK] Volume 'db-data' đã được tạo."

echo ""
echo "========================================================"
echo " BƯỚC 3: Kiểm tra tài nguyên vừa tạo"
echo "========================================================"

echo "--- Network list ---"
docker network ls | grep app-net

echo "--- Volume list ---"
docker volume ls | grep db-data

echo ""
echo "========================================================"
echo " BƯỚC 4: Khởi chạy Database Container (PostgreSQL)"
echo "========================================================"

docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=SecurePass@123 \
  postgres:15-alpine

echo "[OK] Container 'db-server' (PostgreSQL) đã khởi chạy."
echo "Chờ PostgreSQL khởi động..."
sleep 5

echo ""
echo "========================================================"
echo " BƯỚC 5: Khởi chạy Backend Container"
echo "========================================================"

docker run -d \
  --name app-container \
  --network app-net \
  -p 8080:3000 \
  -e PORT=3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASS=SecurePass@123 \
  hw-backend:v1

echo "[OK] Container 'app-container' (Backend) đã khởi chạy."

echo ""
echo "========================================================"
echo " BƯỚC 6: Kiểm tra trạng thái các Container"
echo "========================================================"

docker ps --filter "network=app-net" \
  --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "========================================================"
echo " BƯỚC 7: Kiểm tra DNS Resolution (ping db-server)"
echo "========================================================"

echo "Ping từ app-container đến db-server qua tên hostname:"
docker exec app-container ping -c 2 db-server

echo ""
echo "========================================================"
echo " BƯỚC 8: Thêm dữ liệu vào PostgreSQL để test Persistence"
echo "========================================================"

docker exec -i db-server psql -U appuser -d appdb <<'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie');
SELECT * FROM users;
EOF

echo ""
echo "========================================================"
echo " BƯỚC 9: Test Data Persistence – Xóa cứng DB Container"
echo "========================================================"

echo "Xóa cứng container db-server (docker rm -f)..."
docker rm -f db-server
echo "[OK] Container 'db-server' đã bị xóa hoàn toàn."

echo ""
echo "Kiểm tra Volume vẫn còn:"
docker volume ls | grep db-data

echo ""
echo "========================================================"
echo " BƯỚC 10: Tái tạo DB Container gắn lại cùng Volume db-data"
echo "========================================================"

docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=SecurePass@123 \
  postgres:15-alpine

echo "[OK] Container 'db-server' mới đã được khởi chạy với Volume db-data cũ."
echo "Chờ PostgreSQL khởi động..."
sleep 5

echo ""
echo "========================================================"
echo " BƯỚC 11: Xác minh dữ liệu không bị mất"
echo "========================================================"

echo "Truy vấn bảng users sau khi tái tạo container:"
docker exec -i db-server psql -U appuser -d appdb -c "SELECT * FROM users;"

echo ""
echo "========================================================"
echo " BƯỚC 12: Kiểm tra chi tiết Network app-net"
echo "========================================================"

docker network inspect app-net

echo ""
echo "========================================================"
echo " HOÀN THÀNH! Dọn dẹp tài nguyên"
echo "========================================================"

echo "Dừng và xóa containers..."
docker rm -f app-container db-server

echo "Xóa Network app-net..."
docker network rm app-net

echo "Xóa Volume db-data..."
docker volume rm db-data

echo "[OK] Đã dọn dẹp toàn bộ tài nguyên."
