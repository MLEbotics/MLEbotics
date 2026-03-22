FROM node:20-alpine AS base
RUN npm install -g pnpm

# ── deps ──────────────────────────────────────────────────────────────────────
FROM base AS deps
WORKDIR /app
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY apps/marketing/package.json ./apps/marketing/
COPY packages/config/package.json ./packages/config/
RUN pnpm install --frozen-lockfile

# ── builder ───────────────────────────────────────────────────────────────────
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm --filter @mlebotics/marketing build

# ── runner (static file server) ──────────────────────────────────────────────
FROM nginx:alpine AS runner
COPY --from=builder /app/apps/marketing/dist /usr/share/nginx/html
EXPOSE 80
