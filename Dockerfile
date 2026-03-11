# Stage 1: Build (The "Kitchen")
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .

# Stage 2: Production (The "Dining Room")
FROM node:22-alpine
WORKDIR /app

# Upgrade system packages to fix zlib and completely remove npm (which we don't need in production anyway) to eliminate all node-pkg vulnerabilities
RUN apk upgrade --no-cache && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx


# Security: Create a non-root user so the app doesn't run with admin privileges
RUN addgroup -S sentinel && adduser -S sentinel -G sentinel
USER sentinel

# Only copy the essential files from the builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000
CMD ["node", "src/index.js"]