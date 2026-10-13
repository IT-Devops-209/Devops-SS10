# ============================================================
# Multi-stage Dockerfile
# Stage 1 (builder): Cài đặt tất cả dependency & build
# Stage 2 (runtime): Chỉ lấy production artifacts từ builder
# ============================================================

# ── Stage 1: Builder ─────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

# Copy file khai báo dependency TRƯỚC để tận dụng Layer Cache:
# Layer này chỉ bị invalidate khi package.json thay đổi,
# không bị ảnh hưởng bởi thay đổi mã nguồn.
COPY package*.json ./

# Cài đặt TẤT CẢ dependencies (bao gồm devDependencies như jest, nodemon)
RUN npm install

# Copy toàn bộ mã nguồn ứng dụng
COPY server.js .

# ── Stage 2: Runtime ─────────────────────────────────────────
FROM node:18-alpine AS runtime

ENV PORT=3000
ENV NODE_ENV=production

WORKDIR /app

# Chỉ trích xuất package.json và node_modules sạch từ builder
COPY --from=builder /app/package*.json ./

# Cài đặt lại chỉ production dependencies trong runtime stage
# → Bỏ hoàn toàn devDependencies (nodemon, jest, supertest)
RUN npm install --omit=dev

# Chỉ copy mã nguồn ứng dụng (không copy node_modules có devDeps)
COPY --from=builder /app/server.js ./

EXPOSE 3000

CMD ["node", "server.js"]
