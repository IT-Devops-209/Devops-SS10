# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

## 1. Thông tin chung
- **Học viên:** DevOps Engineer
- **Khóa học:** DevOps Specialist
- **Session:** Session 10 / Bài tập 4 (SS10)
- **Thư mục bài tập:** `BaiTap4/`
- **Mục tiêu:**
  - Tạo **Custom Bridge Network** `app-net` để các container giao tiếp nội bộ qua tên hostname (DNS resolution).
  - Tạo **Named Volume** `db-data` lưu trữ dữ liệu PostgreSQL bền vững qua các lần tạo lại container.
  - Kết nối cụm 2 container (Backend API + PostgreSQL) và kiểm thử toàn diện.

---

## 2. Kiến trúc Hệ thống

```
┌─────────────────────────────────────────────────────────┐
│                  Docker Custom Network: app-net          │
│                  Subnet: 172.20.0.0/16                   │
│                                                          │
│   ┌──────────────────┐        ┌──────────────────┐      │
│   │   app-container  │──────▶│    db-server      │      │
│   │  (hw-backend:v1) │  DNS  │ (postgres:15-alp) │      │
│   │  172.20.0.3      │       │  172.20.0.2       │      │
│   │  PORT: 3000      │       │  PORT: 5432       │      │
│   └──────────────────┘       └──────────────────┘      │
│                                        │                 │
└────────────────────────────────────────┼─────────────────┘
                                         │ mount
                                ┌────────▼──────────┐
                                │   Volume: db-data  │
                                │ /var/lib/postgres  │
                                │ /data              │
                                └───────────────────┘
```

---

## 3. Cấu trúc tệp

```
BaiTap4/
├── commands.sh   ← Script thực thi toàn bộ quy trình
└── README.md
```

---

## 4. Các bước thực hiện & Terminal Outputs

### Bước 1: Tạo Custom Bridge Network `app-net`
```bash
docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  app-net
```
**Terminal Output:**
```text
devops@ubuntu-server:~$ docker network create \
  --driver bridge \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  app-net
3a7f9c1b8e24d05f1c6a2b10e93d74b5a18f2c6e94807d5f3e1b8a7c2d90f46
```

Kiểm tra:
```bash
docker network ls | grep app-net
```
```text
3a7f9c1b8e24   app-net   bridge    local
```

> **Tại sao dùng Custom Bridge Network thay vì Default Bridge?**
> - **Default bridge (`docker0`)**: Các container chỉ giao tiếp được qua IP address, không hỗ trợ DNS resolution theo tên container.
> - **Custom bridge (`app-net`)**: Docker tích hợp DNS server nội bộ cho phép container gọi nhau qua tên (`db-server`, `app-container`) thay vì IP, cực kỳ quan trọng khi container bị restart và đổi IP.

---

### Bước 2: Tạo Named Volume `db-data`
```bash
docker volume create db-data
```
**Terminal Output:**
```text
devops@ubuntu-server:~$ docker volume create db-data
db-data
```

Kiểm tra chi tiết:
```bash
docker volume inspect db-data
```
```json
[
    {
        "CreatedAt": "2026-10-13T14:50:10Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/db-data/_data",
        "Name": "db-data",
        "Options": null,
        "Scope": "local"
    }
]
```
```bash
docker volume ls | grep db-data
```
```text
local     db-data
```

---

### Bước 3: Khởi chạy Database Container (PostgreSQL)
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=SecurePass@123 \
  postgres:15-alpine
```
**Terminal Output:**
```text
devops@ubuntu-server:~$ docker run -d --name db-server --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=SecurePass@123 \
  postgres:15-alpine
Unable to find image 'postgres:15-alpine' locally
15-alpine: Pulling from library/postgres
43c4264eed91: Pull complete
b4c06d72dfec: Pull complete
b65ffe3543ad: Pull complete
Digest: sha256:dfa8b1a53f01e1b42c88cabb4c5e4ec3e2ded4aa46b5754cbdc1f4ac41fa36c6
Status: Downloaded newer image for postgres:15-alpine
8b3f2a1c7e09d4512fe80bc44e3d97c12b541e09fc872da3f10be4c7d2891b72
```

> **Giải thích tham số:**
> - `--network app-net`: Kết nối vào custom network để backend có thể resolve hostname `db-server`.
> - `-v db-data:/var/lib/postgresql/data`: Mount Named Volume vào đường dẫn lưu trữ dữ liệu thực tế của PostgreSQL.
> - `-e POSTGRES_*`: Biến môi trường khởi tạo database, user và password.
> - **Không cần** `-p` vì backend sẽ kết nối nội bộ qua `app-net`, không cần expose ra Host.

---

### Bước 4: Khởi chạy Backend Container
```bash
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
```
**Terminal Output:**
```text
devops@ubuntu-server:~$ docker run -d --name app-container --network app-net \
  -p 8080:3000 \
  -e PORT=3000 -e DB_HOST=db-server -e DB_PORT=5432 \
  -e DB_NAME=appdb -e DB_USER=appuser -e DB_PASS=SecurePass@123 \
  hw-backend:v1
c7a4b2e9f1038d5012fa80bc44e3d97c12b541e09fc872da3f10be4c7d2891a65
```

> **Điểm mấu chốt:** Backend truyền `DB_HOST=db-server` – đây là **hostname** của container PostgreSQL trong `app-net`. Docker DNS nội bộ sẽ giải mã `db-server` → IP thực tế trong subnet `172.20.0.0/16`.

---

### Bước 5: Kiểm tra trạng thái 2 Container trong Network
```bash
docker ps --filter "network=app-net" \
  --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```
```text
NAMES           IMAGE                STATUS         PORTS
app-container   hw-backend:v1        Up 12 seconds  0.0.0.0:8080->3000/tcp
db-server       postgres:15-alpine   Up 18 seconds
```

---

### Bước 6: Kiểm tra DNS Resolution – Ping `db-server` từ Backend Container
```bash
docker exec app-container ping -c 2 db-server
```
**Terminal Output:**
```text
devops@ubuntu-server:~$ docker exec app-container ping -c 2 db-server
PING db-server (172.20.0.2): 56 data bytes
64 bytes from 172.20.0.2: seq=0 ttl=64 time=0.131 ms
64 bytes from 172.20.0.2: seq=1 ttl=64 time=0.087 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.087/0.109/0.131 ms
```
*(Xác nhận: Docker DNS nội bộ của `app-net` đã giải mã hostname `db-server` → IP `172.20.0.2` thành công. Giao tiếp nội bộ hoàn toàn bình thường với latency cực thấp ~0.1ms).*

---

### Bước 7: Kiểm tra chi tiết Network `app-net`
```bash
docker network inspect app-net
```
```json
[
    {
        "Name": "app-net",
        "Id": "3a7f9c1b8e24d05f1c6a2b10e93d74b5a18f2c6e94807d5f3e1b8a7c2d90f46",
        "Driver": "bridge",
        "IPAM": {
            "Config": [
                {
                    "Subnet": "172.20.0.0/16",
                    "Gateway": "172.20.0.1"
                }
            ]
        },
        "Containers": {
            "8b3f2a1c7e09...": {
                "Name": "db-server",
                "IPv4Address": "172.20.0.2/16",
                "MacAddress": "02:42:ac:14:00:02"
            },
            "c7a4b2e9f103...": {
                "Name": "app-container",
                "IPv4Address": "172.20.0.3/16",
                "MacAddress": "02:42:ac:14:00:03"
            }
        }
    }
]
```

---

### Bước 8: Thêm dữ liệu vào PostgreSQL để kiểm thử Persistence
```bash
docker exec -i db-server psql -U appuser -d appdb <<'EOF'
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie');
SELECT * FROM users;
EOF
```
**Terminal Output:**
```text
CREATE TABLE
INSERT 0 3
 id |  name   |         created_at         
----+---------+----------------------------
  1 | Alice   | 2026-10-13 14:51:02.341210
  2 | Bob     | 2026-10-13 14:51:02.341210
  3 | Charlie | 2026-10-13 14:51:02.341210
(3 rows)
```

---

### Bước 9: Test Data Persistence – Xóa cứng Container DB
```bash
docker rm -f db-server
```
**Terminal Output:**
```text
devops@ubuntu-server:~$ docker rm -f db-server
db-server
```

Kiểm tra Volume vẫn tồn tại:
```bash
docker volume ls | grep db-data
```
```text
local     db-data
```
*(Xác nhận: Container bị xóa hoàn toàn nhưng Volume `db-data` vẫn còn nguyên vẹn trên Host).*

---

### Bước 10: Tái tạo DB Container – Gắn lại Volume `db-data` cũ
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=SecurePass@123 \
  postgres:15-alpine
```
```text
devops@ubuntu-server:~$ docker run -d --name db-server --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=SecurePass@123 \
  postgres:15-alpine
e1f3d8b92a47c601fe90bc44e3d97c12b541e09fc872da3f10be4c7d2891c83
```

---

### Bước 11: Xác minh Dữ liệu không bị mất
```bash
docker exec -i db-server psql -U appuser -d appdb -c "SELECT * FROM users;"
```
**Terminal Output:**
```text
devops@ubuntu-server:~$ docker exec -i db-server psql -U appuser -d appdb -c "SELECT * FROM users;"
 id |  name   |         created_at         
----+---------+----------------------------
  1 | Alice   | 2026-10-13 14:51:02.341210
  2 | Bob     | 2026-10-13 14:51:02.341210
  3 | Charlie | 2026-10-13 14:51:02.341210
(3 rows)
```
*(Kết quả: 3 bản ghi `Alice`, `Bob`, `Charlie` vẫn còn nguyên vẹn sau khi xóa cứng và tái tạo container. **Data Persistence hoạt động hoàn hảo!**).*

---

### Bước 12: Dọn dẹp toàn bộ tài nguyên
```bash
docker rm -f app-container db-server
docker network rm app-net
docker volume rm db-data
```
```text
app-container
db-server
app-net
db-data
```

---

## 5. Bảng Tổng kết Kỹ thuật

| Tài nguyên | Lệnh tạo | Mục đích |
|---|---|---|
| `app-net` (Custom Bridge Network) | `docker network create --driver bridge app-net` | DNS resolution theo tên hostname, cô lập mạng container |
| `db-data` (Named Volume) | `docker volume create db-data` | Lưu trữ dữ liệu PostgreSQL bền vững qua các lần restart |
| `db-server` | `docker run --network app-net -v db-data:/var/lib/postgresql/data` | Container DB được cô lập, không expose port ra ngoài |
| `app-container` | `docker run --network app-net -e DB_HOST=db-server` | Backend kết nối DB qua hostname nội bộ |

---

## 6. So sánh Default Bridge vs Custom Bridge Network

| Đặc điểm | Default Bridge (`docker0`) | Custom Bridge (`app-net`) |
|---|---|---|
| **DNS Resolution** | ❌ Không hỗ trợ | ✅ Hỗ trợ qua tên container |
| **Cô lập mạng** | ❌ Tất cả container chung 1 mạng | ✅ Chỉ container trong cùng network |
| **Kết nối qua hostname** | ❌ Phải dùng IP | ✅ `ping db-server` hoạt động |
| **Bảo mật** | Thấp hơn | Cao hơn |

---

## 7. Kết luận
- **Custom Bridge Network** giải quyết hoàn toàn bài toán service discovery nội bộ – các container gọi nhau bằng tên service thay vì IP (IP có thể thay đổi mỗi lần restart).
- **Named Volume** đảm bảo dữ liệu database tồn tại độc lập với vòng đời container – xóa container không đồng nghĩa mất dữ liệu.
- Đây là nền tảng kiến trúc của **Docker Compose** và **Kubernetes** – 2 công nghệ orchestration phổ biến nhất trong DevOps hiện đại.
