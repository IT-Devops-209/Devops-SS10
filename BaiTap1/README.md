# Bài 1: Báo cáo Kỹ thuật – Phân tích Kiến trúc Container vs Virtual Machine

## 1. Thông tin chung
- **Học viên:** DevOps Engineer
- **Khóa học:** DevOps Specialist
- **Session:** Session 10 / Bài tập 1 (SS10)
- **Thư mục bài tập:** `BaiTap1/`
- **Mục tiêu:**
  - Phân tích kiến trúc VM vs Container, cơ chế Namespaces & cgroups.
  - Trích xuất thông số từ `docker info` và `docker version`.

---

## 2. Bảng So sánh: VM vs Container

| Tiêu chí | Virtual Machine (VM) | Container (Docker) |
|---|---|---|
| **Dung lượng Image** | 4GB – 20GB+ (toàn bộ Guest OS) | 5MB – 500MB (ứng dụng + dependency) |
| **Thời gian khởi động** | 30 giây – vài phút | Dưới 1 giây (~100ms) |
| **Hao phí OS** | Cao (256MB – 2GB RAM/VM) | Rất thấp (chia sẻ kernel Host) |
| **Mức độ cô lập** | Rất mạnh (cô lập phần cứng qua Hypervisor) | Tốt (cô lập OS qua Namespaces + cgroups) |
| **Khả năng mở rộng** | Hạn chế (tài nguyên tĩnh, boot chậm) | Vượt trội (nhẹ, tức thì, scale tự động) |

---

## 3. Thông số Trích xuất từ `docker info`

| Thông số | Giá trị |
|---|---|
| **Server Version** | `27.3.1` |
| **Cgroup Driver** | `systemd` |
| **Cgroup Version** | `2` |
| **Containers** | `3` (Running: 1 / Stopped: 2) |
| **Images** | `5` |
| **Storage Driver** | `overlay2` |

Xem toàn bộ phân tích chi tiết trong tệp [REPORT.md](./REPORT.md).
