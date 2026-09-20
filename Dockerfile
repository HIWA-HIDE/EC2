# ---- Base image ----
FROM node:20-alpine

# ---- App directory ----
WORKDIR /app

# ---- Install dependencies first (better layer caching) ----
COPY package*.json ./
RUN npm ci --omit=dev

# ---- Copy the rest of the source ----
COPY . .

# ---- Runtime ----
ENV NODE_ENV=production
EXPOSE 3000

# Basic container healthcheck (hits the /health route added in server.js)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]
