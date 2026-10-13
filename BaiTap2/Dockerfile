# Sử dụng base image Node.js 18 trên Alpine Linux (nhẹ, bảo mật)
FROM node:18-alpine

# Khai báo biến môi trường cho cổng ứng dụng
ENV PORT=3000

# Thiết lập thư mục làm việc bên trong container
WORKDIR /app

# Copy package.json trước để tận dụng Docker Layer Cache
COPY package.json .

# Cài đặt dependencies (chỉ production)
RUN npm install --omit=dev

# Copy toàn bộ mã nguồn ứng dụng vào container
COPY server.js .

# Khai báo cổng container lắng nghe
EXPOSE 3000

# Khởi chạy ứng dụng theo dạng exec form (không qua shell)
CMD ["node", "server.js"]
