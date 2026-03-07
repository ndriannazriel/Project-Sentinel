# Stage 1: Build (The "Kitchen")
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Stage 2: Production (The "Dining Room")
FROM node:18-alpine
WORKDIR /app

# Security: Create a non-root user so the app doesn't run with admin privileges
RUN addgroup -S sentinel && adduser -S sentinel -G sentinel
USER sentinel

# Only copy the essential files from the builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000
CMD ["node", "src/index.js"]