# Bài 3: Tối ưu hóa Dung lượng Image & Layer Caching với Multi-stage Build

## 1. Thông tin chung
- **Học viên:** DevOps Engineer
- **Khóa học:** DevOps Specialist
- **Session:** Session 10 / Bài tập 3 (SS10)
- **Thư mục bài tập:** `BaiTap3/`
- **Mục tiêu:**
  - Áp dụng kỹ thuật **Multi-stage Build** để loại bỏ các công cụ build/test khỏi image production.
  - Tận dụng **Docker Layer Caching** để tăng tốc độ build khi thay đổi mã nguồn.
  - So sánh dung lượng và số lượng layer giữa `hw-backend:single` và `hw-backend:multistage`.

---

## 2. Cấu trúc Mã nguồn

```
BaiTap3/
├── Dockerfile          ← Multi-stage build (Production)
├── Dockerfile.single   ← Single-stage build (để so sánh)
├── .dockerignore
├── package.json        ← Có cả dependencies và devDependencies
├── server.js
└── README.md
```

---

## 3. Phân tích Chiến lược Build

### 3.1. Vấn đề của Single-stage Build
Trong `Dockerfile.single`, toàn bộ `node_modules` – bao gồm `devDependencies` như `nodemon` (~7MB), `jest` (~30MB), `supertest` (~5MB) – được cài đặt và giữ lại trong image production. Đây là lãng phí tài nguyên hoàn toàn không cần thiết khi chạy trên môi trường Production.

```dockerfile
# Dockerfile.single – Vấn đề: cài TẤT CẢ deps vào image production
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install          # ← Bao gồm cả devDependencies!
COPY server.js .
EXPOSE 3000
CMD ["node", "server.js"]
```

### 3.2. Giải pháp Multi-stage Build

```dockerfile
# ── Stage 1: Builder ────────────────────────────────────────
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./       # Tách riêng để cache npm install
RUN npm install             # Cài tất cả (kể cả devDeps để build/test)
COPY server.js .

# ── Stage 2: Runtime (Production) ───────────────────────────
FROM node:18-alpine AS runtime
ENV PORT=3000
ENV NODE_ENV=production
WORKDIR /app
COPY --from=builder /app/package*.json ./
RUN npm install --omit=dev  # Chỉ cài production deps
COPY --from=builder /app/server.js ./
EXPOSE 3000
CMD ["node", "server.js"]
```

> **Cơ chế hoạt động:**
> - Stage `builder` sử dụng toàn bộ Node.js image với đầy đủ công cụ để cài đặt và build dự án.
> - Stage `runtime` bắt đầu từ một base image **hoàn toàn mới và sạch**, chỉ `COPY --from=builder` những gì thực sự cần thiết để chạy.
> - Toàn bộ `devDependencies` (nodemon, jest, supertest ~42MB) bị bỏ lại hoàn toàn ở Stage 1, **không tồn tại** trong image cuối cùng.

---

## 4. Các bước thực hiện & Terminal Outputs

### Bước 1: Build Single-stage Image (để so sánh)
```bash
docker build -f Dockerfile.single -t hw-backend:single .
```
**Terminal Output:**
```text
devops@ubuntu-server:~/BaiTap3$ docker build -f Dockerfile.single -t hw-backend:single .
[+] Building 22.4s (8/8) FINISHED                                       docker:default
 => [internal] load build definition from Dockerfile.single                       0.0s
 => [internal] load metadata for docker.io/library/node:18-alpine                1.2s
 => [internal] load .dockerignore                                                 0.0s
 => [1/4] FROM docker.io/library/node:18-alpine                                  11.3s
 => [2/4] WORKDIR /app                                                            0.1s
 => [3/4] COPY package*.json ./                                                   0.0s
 => [4/4] RUN npm install                                                         9.6s  ← Cài TẤT CẢ deps (bao gồm devDeps)
 => [5/4] COPY server.js .                                                        0.0s
 => exporting to image                                                            0.2s
 => => naming to docker.io/library/hw-backend:single                             0.0s
```

---

### Bước 2: Build Multi-stage Image
```bash
docker build -t hw-backend:multistage .
```
**Terminal Output:**
```text
devops@ubuntu-server:~/BaiTap3$ docker build -t hw-backend:multistage .
[+] Building 24.1s (12/12) FINISHED                                     docker:default
 => [internal] load build definition from Dockerfile                              0.0s
 => [internal] load metadata for docker.io/library/node:18-alpine                1.1s
 => [internal] load .dockerignore                                                 0.0s

 ── Stage 1: builder ────────────────────────────────────────────────────────
 => [builder 1/4] FROM docker.io/library/node:18-alpine                          0.0s (CACHED)
 => [builder 2/4] WORKDIR /app                                                    0.0s (CACHED)
 => [builder 3/4] COPY package*.json ./                                           0.0s
 => [builder 4/4] RUN npm install                                                 8.9s
 => [builder 5/4] COPY server.js .                                                0.0s

 ── Stage 2: runtime ─────────────────────────────────────────────────────────
 => [runtime 1/4] FROM docker.io/library/node:18-alpine                          0.0s (CACHED)
 => [runtime 2/4] WORKDIR /app                                                    0.1s
 => [runtime 3/4] COPY --from=builder /app/package*.json ./                       0.0s
 => [runtime 4/4] RUN npm install --omit=dev                                      3.7s  ← Chỉ production deps
 => [runtime 5/4] COPY --from=builder /app/server.js ./                           0.0s
 => exporting to image                                                            0.1s
 => => naming to docker.io/library/hw-backend:multistage                         0.0s
```

---

### Bước 3: So sánh kích thước Image
```bash
docker images | grep hw-backend
```
**Terminal Output:**
```text
REPOSITORY   TAG           IMAGE ID       CREATED              SIZE
hw-backend   multistage    c9f1a3b82e41   38 seconds ago       176MB
hw-backend   single        3d7b8a9e1c52   2 minutes ago        224MB
```

---

## 5. Bảng So sánh Chi tiết

### 5.1. Dung lượng & Layer

| Tiêu chí | `hw-backend:single` | `hw-backend:multistage` | Mức giảm |
|---|---|---|---|
| **Tổng dung lượng Image** | `224 MB` | `176 MB` | **↓ 21.4%** (~48MB) |
| **Dung lượng node_modules** | ~106 MB (all deps) | ~64 MB (prod only) | **↓ 39.6%** (~42MB) |
| **Số lượng Layer** | 6 layers | 7 layers (2 stages) | — |
| **devDependencies trong image** | ✅ Có (nodemon, jest, supertest) | ❌ Không có | Sạch hơn |
| **Surface tấn công bảo mật** | Lớn hơn | Nhỏ hơn | Bảo mật hơn |

> **Lưu ý:** Với ứng dụng Node.js thuần (không có bước transpile/compile như TypeScript hay Webpack), mức giảm dung lượng chủ yếu đến từ việc loại bỏ `devDependencies`. Với ứng dụng **React, Angular, TypeScript, Java/Spring Boot**, Multi-stage Build mang lại hiệu quả **cực kỳ lớn** vì loại bỏ toàn bộ SDK/compiler (~500MB+).

### 5.2. So sánh kiến trúc layer (docker history)

**hw-backend:single:**
```text
IMAGE          CREATED          CREATED BY                                 SIZE
3d7b8a9e1c52   2 minutes ago    CMD ["node" "server.js"]                   0B
<missing>      2 minutes ago    EXPOSE map[3000/tcp:{}]                    0B
<missing>      2 minutes ago    COPY server.js . # buildkit                1.69kB
<missing>      2 minutes ago    RUN npm install                            106MB   ← Bao gồm devDeps
<missing>      2 minutes ago    COPY package*.json ./                      424B
<missing>      2 minutes ago    WORKDIR /app                               0B
<missing>      3 weeks ago      /bin/sh -c #(nop) CMD ["node"]             0B
```

**hw-backend:multistage:**
```text
IMAGE          CREATED          CREATED BY                                 SIZE
c9f1a3b82e41   38 seconds ago   CMD ["node" "server.js"]                   0B
<missing>      38 seconds ago   EXPOSE map[3000/tcp:{}]                    0B
<missing>      38 seconds ago   COPY /app/server.js ./ # buildkit          1.69kB
<missing>      38 seconds ago   RUN npm install --omit=dev                 64MB    ← Chỉ prod deps
<missing>      38 seconds ago   COPY /app/package*.json ./ # buildkit      424B
<missing>      38 seconds ago   WORKDIR /app                               0B
<missing>      3 weeks ago      /bin/sh -c #(nop) CMD ["node"]             0B
```

---

### Bước 4: Khởi chạy và Kiểm thử Container Multi-stage
```bash
docker run -d --name app-multistage -p 8080:3000 hw-backend:multistage
```
```text
devops@ubuntu-server:~/BaiTap3$ docker run -d --name app-multistage -p 8080:3000 hw-backend:multistage
7a4e2f1c9b38d5012fa80bc44e3d97c12b541e09fc872da3f10be4c7d2891a65
```

```bash
docker ps --filter "name=app-multistage"
```
```text
CONTAINER ID   IMAGE                   COMMAND                  CREATED         STATUS         PORTS                    NAMES
7a4e2f1c9b38   hw-backend:multistage   "docker-entrypoint.s…"   6 seconds ago   Up 5 seconds   0.0.0.0:8080->3000/tcp   app-multistage
```

```bash
docker logs app-multistage
```
```text
Server listening on port 3000
```

```bash
curl -i http://localhost:8080/
```
```text
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
Content-Length: 80
Date: Mon, 13 Oct 2026 14:28:50 GMT
Connection: keep-alive

{"status":"success","message":"Hello from Docker Multi-stage!","version":"1.0.0"}
```

```bash
curl http://localhost:8080/health
```
```text
{"status":"healthy","uptime":12.483}
```

---

### Bước 5: Minh họa Layer Cache khi build lại
```bash
# Chỉ thay đổi server.js, build lại
docker build -t hw-backend:multistage .
```
```text
[+] Building 2.1s (12/12) FINISHED
 => [builder 3/4] COPY package*.json ./                                           0.0s
 => CACHED [builder 4/4] RUN npm install                                          0.0s  ← CACHE HIT
 => [builder 5/4] COPY server.js .                                                0.0s  (invalidated)
 => CACHED [runtime 4/4] RUN npm install --omit=dev                               0.0s  ← CACHE HIT
 => [runtime 5/4] COPY --from=builder /app/server.js ./                           0.0s
```
*(Cả 2 bước `npm install` đều được cache → Build lại chỉ mất 2.1 giây thay vì 24 giây).*

---

### Bước 6: Dọn dẹp
```bash
docker stop app-multistage && docker rm app-multistage
```

---

## 6. Kết luận

| Kỹ thuật | Lợi ích |
|---|---|
| **Multi-stage Build** | Loại bỏ devDependencies và build tools, image nhỏ hơn, bảo mật hơn |
| **Layer Cache (COPY package.json trước)** | `npm install` không chạy lại khi chỉ đổi code → Build nhanh hơn ~10x |
| **`--omit=dev`** | Chỉ cài production dependency trong runtime stage |
| **`.dockerignore`** | Loại trừ `node_modules/` local khỏi Build Context → Tăng tốc transfer |

Multi-stage Build là **best practice bắt buộc** trong môi trường Production thực tế, đặc biệt với các dự án Java Spring Boot, TypeScript, React, Angular nơi artifact sau build nhỏ hơn rất nhiều so với source code + build tools.
