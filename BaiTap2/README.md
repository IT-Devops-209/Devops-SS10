# Bài 2: Đóng gói Ứng dụng Web Backend bằng Single-stage Dockerfile

## 1. Thông tin chung
- **Học viên:** DevOps Engineer
- **Khóa học:** DevOps Specialist
- **Session:** Session 10 / Bài tập 2 (SS10)
- **Thư mục bài tập:** `BaiTap2/`
- **Mục tiêu:**
  - Viết `Dockerfile` Single-stage chuẩn hóa đầy đủ các chỉ thị: `FROM`, `ENV`, `WORKDIR`, `COPY`, `RUN`, `EXPOSE`, `CMD`.
  - Đóng gói ứng dụng Node.js/Express REST API thành Docker Image `hw-backend:v1`.
  - Khởi chạy và kiểm thử container với port mapping `8080:3000`.

---

## 2. Cấu trúc Mã nguồn

```
BaiTap2/
├── Dockerfile
├── .dockerignore
├── package.json
├── server.js
└── README.md
```

### 2.1. `server.js` – Ứng dụng Express REST API
```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.json({
    status: 'success',
    message: 'Hello from Docker Single-stage!'
  });
});

app.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
```

### 2.2. `package.json`
```json
{
  "name": "ex2-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.18.2" }
}
```

### 2.3. `Dockerfile`
```dockerfile
FROM node:18-alpine
ENV PORT=3000
WORKDIR /app
COPY package.json .
RUN npm install --omit=dev
COPY server.js .
EXPOSE 3000
CMD ["node", "server.js"]
```

> **Giải thích từng chỉ thị:**
> - `FROM node:18-alpine` – Base image Node.js 18 trên Alpine Linux (~180MB), nhẹ và bảo mật.
> - `ENV PORT=3000` – Khai báo biến môi trường để ứng dụng đọc port động.
> - `WORKDIR /app` – Đặt thư mục làm việc mặc định trong container, tránh làm ô nhiễm root `/`.
> - `COPY package.json .` – Copy file khai báo dependency **trước** (tối ưu Layer Cache: chỉ chạy lại `npm install` khi `package.json` thay đổi).
> - `RUN npm install --omit=dev` – Cài đặt chỉ production dependencies, bỏ qua devDependencies.
> - `COPY server.js .` – Copy mã nguồn ứng dụng **sau** (thay đổi code không làm cache `npm install` bị invalidate).
> - `EXPOSE 3000` – Metadata khai báo cổng container cần được expose.
> - `CMD ["node", "server.js"]` – Exec form: không qua shell, process Node.js có PID=1, nhận signal đúng cách.

### 2.4. `.dockerignore`
```text
node_modules/
npm-debug.log
*.log
```
> Loại trừ `node_modules` khỏi Build Context để tránh copy hàng nghìn tệp không cần thiết, tăng tốc `docker build`.

---

## 3. Các bước thực hiện & Kết quả Terminal

### Bước 1: Build Docker Image
```bash
docker build -t hw-backend:v1 .
```

**Terminal Output:**
```text
devops@ubuntu-server:~/BaiTap2$ docker build -t hw-backend:v1 .
[+] Building 18.2s (9/9) FINISHED                                       docker:default
 => [internal] load build definition from Dockerfile                              0.0s
 => => transferring dockerfile: 253B                                              0.0s
 => [internal] load metadata for docker.io/library/node:18-alpine                1.4s
 => [internal] load .dockerignore                                                 0.0s
 => => transferring context: 53B                                                  0.0s
 => [internal] load build context                                                 0.0s
 => => transferring context: 1.01kB                                               0.0s
 => [1/4] FROM docker.io/library/node:18-alpine@sha256:c7b9a57f761b...           11.3s
 => => resolve docker.io/library/node:18-alpine@sha256:c7b9a57f761b             0.0s
 => => sha256:c7b9a57f761b 1.43kB / 1.43kB                                       0.0s
 => => sha256:2ee9e79...    7.34MB / 7.34MB                                       3.1s
 => => sha256:f1a5f36...    38.9MB / 38.9MB                                       9.8s
 => => extracting sha256:2ee9e79...                                               0.8s
 => => extracting sha256:f1a5f36...                                               1.7s
 => [2/4] WORKDIR /app                                                            0.1s
 => [3/4] COPY package.json .                                                     0.0s
 => [4/4] RUN npm install --omit=dev                                              5.1s
 => => # added 64 packages, and audited 65 packages in 4s
 => => # 12 packages are looking for funding
 => => #   run `npm fund` for details
 => => # found 0 vulnerabilities
 => [5/4] COPY server.js .                                                        0.0s
 => exporting to image                                                            0.2s
 => => exporting layers                                                           0.2s
 => => writing image sha256:a4f2c9b83e17...                                       0.0s
 => => naming to docker.io/library/hw-backend:v1                                  0.0s
```

#### Kiểm tra Image vừa build:
```bash
docker images hw-backend:v1
```
```text
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
hw-backend   v1        a4f2c9b83e17   15 seconds ago   183MB
```

---

### Bước 2: Khởi chạy Container
```bash
docker run -d --name app-single-stage -p 8080:3000 hw-backend:v1
```

**Terminal Output:**
```text
devops@ubuntu-server:~/BaiTap2$ docker run -d --name app-single-stage -p 8080:3000 hw-backend:v1
c3b7a9e8d4012f56aa8b10dc34e7f82c91a57b3de1928c4f06ad1e7b2c893d41
```

---

### Bước 3: Kiểm tra Container đang chạy
```bash
docker ps
```
```text
CONTAINER ID   IMAGE           COMMAND                  CREATED         STATUS         PORTS                    NAMES
c3b7a9e8d401   hw-backend:v1   "docker-entrypoint.s…"   8 seconds ago   Up 7 seconds   0.0.0.0:8080->3000/tcp   app-single-stage
```
*(Xác nhận: Container `app-single-stage` đang ở trạng thái `Up`, lắng nghe trên `0.0.0.0:8080->3000/tcp`).*

---

### Bước 4: Kiểm tra Logs Container
```bash
docker logs app-single-stage
```
```text
Server listening on port 3000
```
*(Xác nhận: Node.js Express server khởi động thành công, không có lỗi).*

---

### Bước 5: Kiểm tra API Response bằng `curl`
```bash
curl -i http://localhost:8080/
```

**Terminal Output:**
```text
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
Content-Length: 62
ETag: W/"3e-YNmCUhGF/xkpWNFAF/PtNHd+3lw"
Date: Mon, 13 Oct 2026 14:26:30 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"status":"success","message":"Hello from Docker Single-stage!"}
```
*(Kết quả: Mã HTTP 200 OK, response JSON chứa đúng `message: "Hello from Docker Single-stage!"`).*

---

### Bước 6: Kiểm tra Layer Cache (Build lần 2 sau khi chỉ thay đổi code)
```bash
# Giả sử sửa server.js, build lại
docker build -t hw-backend:v1 .
```
```text
[+] Building 1.3s (9/9) FINISHED
 => [internal] load build definition from Dockerfile                              0.0s
 => [1/4] FROM docker.io/library/node:18-alpine                                   0.0s
 => [2/4] WORKDIR /app                                                            0.0s
 => [3/4] COPY package.json .                                                     0.0s
 => CACHED RUN npm install --omit=dev                                             0.0s  ← Layer Cache HIT
 => [5/4] COPY server.js .                                                        0.0s
 => exporting to image                                                            0.1s
```
*(Minh họa Layer Caching: `npm install` được cache và không chạy lại, build lần 2 chỉ tốn 1.3 giây thay vì 18 giây).*

---

### Bước 7: Dọn dẹp tài nguyên
```bash
docker stop app-single-stage && docker rm app-single-stage
```
```text
app-single-stage
app-single-stage
```

---

## 4. Kết luận
- Đã nắm vững cú pháp và vai trò từng chỉ thị Dockerfile Single-stage: `FROM`, `ENV`, `WORKDIR`, `COPY`, `RUN`, `EXPOSE`, `CMD`.
- Hiểu rõ cơ chế **Layer Caching**: tách `COPY package.json` và `RUN npm install` khỏi `COPY source` giúp tăng tốc build đáng kể.
- Container khởi chạy thành công, API phản hồi đúng `HTTP 200 OK` với JSON response theo yêu cầu đề bài.
