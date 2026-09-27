# ---- Base image ----
FROM node:20-alpine

# ---- App directory ----
WORKDIR /app

# ---- Install dependencies first (better layer caching) ----
COPY package*.json ./
RUN npm ci --omit=dev

# ---- Copy the rest of the source ----
COPY . .

# ---- Security hardening ----
# 1. Patch Alpine OS packages (e.g. libssl/libcrypto CVEs) to their latest
#    fixed versions, even though the base image tag itself hasn't changed.
# 2. Remove npm's own bundled tooling from the final image. It's only
#    needed during `npm ci` above - the app itself only ever runs via
#    `node`, never `npm`, so this also removes npm's own vulnerable
#    transitive dependencies (tar, glob, minimatch, etc.) that Trivy
#    flags but that are never actually executed in production.
RUN apk update && apk upgrade --no-cache \
    && rm -rf /usr/local/lib/node_modules/npm \
    && rm -rf /tmp/* /var/cache/apk/*

# ---- Runtime ----
ENV NODE_ENV=production
EXPOSE 3000

# Basic container healthcheck (hits the /health route added in server.js)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]
