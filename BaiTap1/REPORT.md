# BÁO CÁO KỸ THUẬT: PHÂN TÍCH KIẾN TRÚC CONTAINER vs VIRTUAL MACHINE

## 1. Thông tin chung
- **Học viên:** DevOps Engineer
- **Khóa học:** DevOps Specialist
- **Session:** Session 10 / Bài tập 1 (SS10)
- **Thư mục bài tập:** `BaiTap1/`
- **Mục tiêu:**
  - Phân tích chuyên sâu sự khác biệt kiến trúc giữa ảo hóa phần cứng (VM/Hypervisor) và ảo hóa hệ điều hành (Container Engine).
  - Trình bày cơ chế cô lập kernel (Namespaces) và quản lý tài nguyên (Control Groups - cgroups) của Linux.
  - Trích xuất và phân tích thông số cấu hình Docker từ đầu ra lệnh `docker info`.

---

## 2. Bảng So sánh: Virtual Machine vs Container

| Tiêu chí | Virtual Machine (VM) | Container (Docker) |
|---|---|---|
| **Dung lượng Image** | **Lớn** – thường từ **4GB – 20GB+** do phải đóng gói toàn bộ Guest OS (kernel, thư viện hệ thống, binaries) | **Nhỏ** – thường chỉ **5MB – 500MB**, chỉ đóng gói ứng dụng và các dependency cần thiết. VD: `alpine:latest` chỉ ~7MB, `nginx:alpine` ~43MB |
| **Thời gian khởi động** | **Chậm** – từ **30 giây đến vài phút** do phải khởi động toàn bộ Guest OS, BIOS/UEFI, và hệ điều hành đầy đủ | **Nhanh** – thường dưới **1 giây** (~100ms–500ms) do chỉ cần khởi tạo process mới, không cần boot OS |
| **Hao phí OS (OS Overhead)** | **Cao** – mỗi VM duy trì một bản sao OS độc lập, tiêu tốn từ **256MB – 2GB RAM** chỉ để duy trì hệ điều hành | **Thấp** – mọi container chia sẻ chung kernel của Host OS. Một container Alpine chỉ tiêu tốn ~**1–5MB RAM** overhead |
| **Mức độ cô lập** | **Rất mạnh** – cô lập hoàn toàn ở tầng phần cứng ảo thông qua Hypervisor. Mỗi VM có kernel và bộ nhớ riêng hoàn toàn độc lập. Thích hợp cho bảo mật cấp cao | **Tốt** – cô lập ở tầng hệ điều hành qua **Namespaces + cgroups**. Chia sẻ kernel nên lý thuyết rủi ro bảo mật cao hơn VM, nhưng đủ đáp ứng hầu hết yêu cầu doanh nghiệp |
| **Khả năng mở rộng (Scalability)** | **Hạn chế** – mỗi VM cần phân bổ tài nguyên tĩnh (vCPU, RAM cố định). Khởi động chậm cản trở auto-scaling nhanh | **Vượt trội** – container nhẹ, khởi động tức thì, dễ dàng scale từ 1 lên hàng nghìn instance trong vài giây với Kubernetes hoặc Docker Swarm |

---

## 3. Cơ chế Cô lập và Quản lý Tài nguyên trong Container

### 3.1. Linux Namespaces – Cơ chế Cô lập (Isolation)

**Namespaces** là tính năng của Linux Kernel cho phép tạo ra các **"không gian tên" độc lập**, mỗi container được đặt vào một tập namespace riêng biệt, khiến nó "tưởng rằng" mình đang chạy trên một hệ thống riêng biệt hoàn toàn.

Docker sử dụng 6 loại Namespaces chính:

| Namespace | Viết tắt | Mục đích |
|---|---|---|
| **PID Namespace** | `pid` | Cô lập không gian Process ID. Container chỉ thấy các process của chính nó. Process đầu tiên trong container luôn có PID=1 (dù trên Host có PID khác) |
| **Network Namespace** | `net` | Cô lập giao diện mạng. Mỗi container có network interface (`eth0`), địa chỉ IP, bảng routing và iptables rules riêng hoàn toàn độc lập |
| **Mount Namespace** | `mnt` | Cô lập filesystem mount points. Container có hệ thống tệp tin riêng, không thấy filesystem của Host hay container khác (trừ khi được mount rõ ràng qua Volume) |
| **UTS Namespace** | `uts` | Cô lập hostname và domain name. Mỗi container có thể có hostname riêng (VD: `my-web`) |
| **IPC Namespace** | `ipc` | Cô lập Inter-Process Communication (message queues, semaphores, shared memory) |
| **User Namespace** | `user` | Cô lập User ID và Group ID. Cho phép container chạy với quyền root bên trong nhưng thực tế là user thường trên Host |

**Ví dụ thực tiễn:** Khi chạy `docker run -d --name my-web nginx:alpine`, Docker tạo một bộ Namespace mới. Process `nginx` bên trong container có PID=1 (từ góc nhìn của container), nhưng trên Host có thể là PID=2847. Container có địa chỉ IP riêng `172.17.0.2`, trong khi Host có IP thực tế.

---

### 3.2. Linux Control Groups (cgroups) – Cơ chế Quản lý Tài nguyên

**cgroups** (Control Groups) là tính năng Linux Kernel cho phép **phân bổ, giới hạn và theo dõi** tài nguyên phần cứng (CPU, RAM, Disk I/O, Network I/O) cho từng nhóm process. Đây là nền tảng giúp Docker đảm bảo các container không "cướp" tài nguyên của nhau.

**Các tài nguyên được kiểm soát bởi cgroups:**

| Tài nguyên | Cờ Docker | Mô tả |
|---|---|---|
| **CPU (giới hạn)** | `--cpus="1.5"` | Giới hạn container chỉ sử dụng tối đa 1.5 CPU cores |
| **CPU (ưu tiên)** | `--cpu-shares=512` | Phân bổ CPU theo tỷ lệ ưu tiên tương đối (mặc định 1024) |
| **RAM** | `--memory="512m"` | Giới hạn container không vượt quá 512MB RAM |
| **Swap** | `--memory-swap="1g"` | Giới hạn tổng RAM + Swap |
| **Disk I/O** | `--blkio-weight=300` | Giới hạn băng thông đọc/ghi đĩa |

**Ví dụ thực tiễn:** Khởi chạy container bị giới hạn tài nguyên:
```bash
docker run -d \
  --name api-server \
  --cpus="0.5" \
  --memory="256m" \
  nginx:alpine
```
Lệnh trên đảm bảo container `api-server` chỉ được dùng tối đa 50% 1 CPU core và 256MB RAM, dù Host có 8 CPU và 32GB RAM.

---

## 4. Phân tích Thông số từ lệnh `docker info` và `docker version`

### 4.1. Kết quả lệnh `docker version`

```bash
docker version
```

```text
Client: Docker Engine - Community
 Version:           27.3.1
 API version:       1.47
 Go version:        go1.22.7
 Git commit:        ce12230
 Built:             Fri Sep 20 11:41:00 2024
 OS/Arch:           linux/amd64
 Context:           default

Server: Docker Engine - Community
 Engine:
  Version:          27.3.1
  API version:      1.47 (minimum version 1.24)
  Go version:       go1.22.7
  Git commit:       4123503
  Built:            Fri Sep 20 11:41:00 2024
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          1.7.22
  GitCommit:        7f7fdf5fed64eb6a7caf99b3e12efcf9d60e311c
 runc:
  Version:          1.1.14
  GitCommit:        v1.1.14-0-g2c9f560
 docker-init:
  Version:          0.19.0
  GitCommit:        de40ad0
```

> **Xác nhận:** Lệnh thực thi thành công bằng user thường `devops` mà không cần `sudo`, chứng tỏ user đã được thêm vào group `docker`.

---

### 4.2. Kết quả lệnh `docker info` (Toàn bộ)

```bash
docker info
```

```text
Client: Docker Engine - Community
 Version:    27.3.1
 Context:    default
 Debug Mode: false
 Plugins:
  buildx: Docker Buildx (Docker Inc.)
    Version:  v0.17.1
    Path:     /usr/libexec/docker/cli-plugins/docker-buildx
  compose: Docker Compose (Docker Inc.)
    Version:  v2.29.7
    Path:     /usr/libexec/docker/cli-plugins/docker-compose

Server:
 Containers: 3
  Running: 1
  Paused: 0
  Stopped: 2
 Images: 5
 Server Version: 27.3.1
 Storage Driver: overlay2
  Backing Filesystem: extfs
  Supports d_type: true
  Using metacopy: false
 Logging Driver: json-file
 Cgroup Driver: systemd
 Cgroup Version: 2
 Plugins:
  Volume: local
  Network: bridge host ipvlan macvlan null overlay
  Log: awslogs fluentd gcplogs gelf journald json-file local splunk syslog
 Swarm: inactive
 Runtimes: io.containerd.runc.v2 runc
 Default Runtime: runc
 Init Binary: docker-init
 containerd version: 7f7fdf5fed64eb6a7caf99b3e12efcf9d60e311c
 runc version: v1.1.14-0-g2c9f560
 init version: de40ad0
 Security Options:
  apparmor
  seccomp
   Profile: builtin
  cgroup2
 Kernel Version: 6.8.0-45-generic
 Operating System: Ubuntu 24.04.1 LTS
 OSType: linux
 Architecture: x86_64
 CPUs: 2
 Total Memory: 3.824GiB
 Name: ubuntu-server
 ID: 9f7b6b1a-8e2c-4933-911e-dc1e089201a4
 Docker Root Dir: /var/lib/docker
 Debug Mode: false
 Experimental: false
 Insecure Registries:
  127.0.0.0/8
 Live Restore Enabled: false
```

---

### 4.3. Kiểm tra Cgroup Driver (Lọc nhanh)

```bash
docker info | grep -i cgroup
```

```text
 Cgroup Driver: systemd
 Cgroup Version: 2
  cgroup2
```

---

### 4.4. Bảng Trích xuất Thông số Quan trọng từ `docker info`

| Thông số | Giá trị | Ý nghĩa |
|---|---|---|
| **Server Version** | `27.3.1` | Phiên bản Docker Engine đang chạy trên máy chủ |
| **Cgroup Driver** | `systemd` | Sử dụng systemd để quản lý cgroup – đúng chuẩn khuyến nghị cho Ubuntu 24.04 (đồng bộ với containerd và kubelet) |
| **Cgroup Version** | `2` | Đang dùng cgroup v2 – phiên bản mới hơn với nhiều tính năng nâng cao hơn cgroup v1 |
| **Containers** | `3` (1 Running / 0 Paused / 2 Stopped) | Tổng số container trên hệ thống, bao gồm cả đang chạy và đã dừng |
| **Images** | `5` | Số lượng Docker image hiện có trong cache cục bộ |
| **Storage Driver** | `overlay2` | Driver lưu trữ layer của container – `overlay2` là chuẩn mặc định hiệu năng cao trên Linux |
| **OS / Architecture** | `Ubuntu 24.04.1 LTS / x86_64` | Hệ điều hành Host và kiến trúc CPU |
| **CPU / RAM** | `2 CPUs / 3.824 GiB` | Tài nguyên phần cứng của máy Host |
| **Kernel Version** | `6.8.0-45-generic` | Phiên bản Linux Kernel – quan trọng vì Docker chia sẻ kernel này với tất cả container |

---

## 5. Phân tích Lý do Doanh nghiệp Chuyển từ VPS sang Docker

Dựa trên phân tích kiến trúc ở trên, có 5 lý do cốt lõi thúc đẩy doanh nghiệp hiện đại chuyển đổi từ mô hình VPS/VM sang triển khai Docker:

1. **Tối ưu chi phí hạ tầng:** Một máy chủ 16 CPU / 64GB RAM có thể chạy 3–5 VMs, nhưng có thể chạy 50–200 containers với cùng tài nguyên đó nhờ cơ chế chia sẻ kernel và overhead cực thấp.

2. **Tăng tốc độ triển khai (Deployment Speed):** Phiên bản mới không mất 5–10 phút chờ VM boot, mà chỉ cần `docker pull` + `docker run` trong vài giây.

3. **Tính nhất quán môi trường (Environment Parity):** Docker image đóng gói tất cả dependency, loại bỏ hoàn toàn lỗi "It works on my machine" giữa Dev, Test và Production.

4. **Khả năng mở rộng linh hoạt (Auto-scaling):** Kết hợp với Kubernetes, hệ thống có thể tự động nhân bản container trong vài giây khi tải tăng, rồi thu hẹp lại khi tải giảm – điều mà VM không thể làm được với tốc độ tương đương.

5. **CI/CD Pipeline hiệu quả:** Docker image là artifact chuẩn trong pipeline CI/CD (GitLab CI, GitHub Actions, Jenkins), cho phép build một lần, deploy mọi nơi với kết quả nhất quán.

---

## 6. Kết luận

Containerization với Docker không phải là "tốt hơn tuyệt đối" so với VM trong mọi trường hợp. VM vẫn là lựa chọn phù hợp khi cần cô lập bảo mật cấp phần cứng (chạy kernel khác nhau, workload untrusted). Tuy nhiên, đối với ứng dụng web, microservices, CI/CD, và triển khai cloud-native hiện đại, Docker mang lại lợi thế vượt trội toàn diện về tốc độ, chi phí và khả năng mở rộng.
