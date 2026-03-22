# MLEbotics Platform

> A modular, phased architecture for a global Robotics + AI Automation Operating System.

Live site: **[mlebotics.com](https://mlebotics.com)**

---

## Vision

MLEbotics is a multi-tenant platform that lets teams deploy, monitor, and orchestrate physical robots and AI agents from a single dashboard. It is built to grow from a solo dev project to a scalable cloud product, one phase at a time.

---

## Monorepo Structure

```
mlebotics.com/           ← workspace root (Turborepo + pnpm)
├── apps/
│   ├── console/         ← Operator dashboard (Next.js 15, port 3001)
│   ├── marketing/       ← Public website (Astro 4, port 4321)
│   ├── studio/          ← Visual workflow editor (Next.js 15, port 3002)
│   └── docs/            ← Platform documentation (Phase 5)
├── packages/
│   ├── api/             ← tRPC v11 router (health, user, organization)
│   ├── ui/              ← Shared React components (Button, Card)
│   ├── utils/           ← Shared utilities (cn, etc.)
│   └── config/          ← Shared tsconfig, eslint, tailwind configs
├── platform/            ← Phase 3 TypeScript interfaces
│   ├── world/           ← World, Entity, Stream types
│   ├── automation/      ← Workflow, Trigger, Step, Run types
│   ├── plugins/         ← PluginManifest, Plugin, Permission types
│   └── shared/          ← PaginatedResult, ApiError, AuditEvent types
├── robotics/            ← Phase 4 robotics layer
│   ├── agents/          ← AgentRuntime, RobotAgent, RobotCommand types
│   └── adapters/
│       ├── ros2-bridge/ ← ROS2 ↔ Platform bridge skeleton
│       ├── mqtt-bridge/ ← MQTT ↔ Platform bridge skeleton
│       └── rtsp-bridge/ ← RTSP video ↔ Platform bridge skeleton
└── infra/
    └── db/prisma/       ← Prisma schema (Organization, User, Membership, Role)
```

---

## Apps

| App | Stack | Port | Description |
|---|---|---|---|
| `apps/console` | Next.js 15 + tRPC + Tailwind | 3001 | Operator dashboard — robots, workflows, automation |
| `apps/marketing` | Astro 4 + Tailwind | 4321 | Public marketing site |
| `apps/studio` | Next.js 15 + Tailwind | 3002 | Visual workflow/world editor |
| `apps/docs` | Markdown | — | Platform docs (Phase 5) |

---

## Phase Roadmap

| Phase | Summary | Status |
|---|---|---|
| **1** | Monorepo + UI shells + Auth scaffold | ✅ Complete |
| **2** | Identity (Prisma) + API layer (tRPC) | ✅ Complete |
| **3** | Platform engine interfaces (world, automation, plugins) | ✅ Complete |
| **4** | Robotics layer — agents + hardware adapters skeleton | ✅ Complete |
| **5** | Autonomy engine + Marketplace + Enterprise docs | 📋 Planned |

---

## Getting Started

```bash
# Install dependencies
pnpm install

# Run all apps in dev mode (parallel)
pnpm dev

# Run a specific app
pnpm dev:marketing    # http://localhost:4321
pnpm dev:console      # http://localhost:3001
pnpm dev:studio       # http://localhost:3002
pnpm dev:docs         # http://localhost:3003

# Build all apps (respects Turborepo dependency order)
pnpm build

# Build a specific app
pnpm build:marketing
pnpm build:console
pnpm build:studio
pnpm build:docs

# Serve built output (production mode — requires build first)
pnpm start             # all apps
pnpm start:marketing   # astro preview on :4321
pnpm start:console     # next start on :3001
pnpm start:studio      # next start on :3002
pnpm start:docs        # next start on :3003

# Type check all
pnpm typecheck
```

---

## Deployment (Vercel)

The platform uses **4 separate Vercel projects** from the same git repo,
all deployed under `mlebotics.com`:

| App | Vercel project | Domain |
|---|---|---|
| `apps/marketing` | `mlebotics` (main) | `https://mlebotics.com` |
| `apps/console` | `mlebotics-console` | proxied at `/console` |
| `apps/studio` | `mlebotics-studio` | proxied at `/studio` |
| `apps/docs` | `mlebotics-docs` | proxied at `/docs` |

### Step 1 — Deploy the three sub-apps first

For **each** of `apps/console`, `apps/studio`, `apps/docs`:

1. Create a new Vercel project → Import the monorepo git repo
2. Set **Root Directory** to the app folder (e.g. `apps/console`)
3. Vercel will auto-detect Next.js. The `vercel.json` inside each app folder provides the build command and output directory.
4. Add the environment variable in Vercel dashboard → **Environment Variables**:
   - `NEXT_PUBLIC_BASE_PATH` = `/console` (or `/studio` or `/docs`)
5. Deploy. Note the production URL (e.g. `https://mlebotics-console.vercel.app`).

### Step 2 — Deploy the marketing app (main domain)

1. Create a Vercel project for the repo root (`apps/marketing` is the main site)
2. **Root Directory**: leave blank (repo root) — the root `vercel.json` handles the build
3. Set these environment variables in Vercel dashboard:
   - `CONSOLE_APP_URL` = full URL of the console deployment, **without trailing slash**  
     e.g. `https://mlebotics-console.vercel.app`
   - `STUDIO_APP_URL` = e.g. `https://mlebotics-studio.vercel.app`
   - `DOCS_APP_URL` = e.g. `https://mlebotics-docs.vercel.app`
4. Assign the custom domain `mlebotics.com` to this project
5. Deploy

After both steps, `mlebotics.com` serves the marketing site and transparently
proxies `/console/**`, `/studio/**`, `/docs/**` to the respective deployments.

### How the routing works

```
https://mlebotics.com/          → apps/marketing (Astro, static)
https://mlebotics.com/console/* → apps/console  (Next.js, basePath=/console)
https://mlebotics.com/studio/*  → apps/studio   (Next.js, basePath=/studio)
https://mlebotics.com/docs/*    → apps/docs     (Next.js, basePath=/docs)
```

The root `vercel.json` rewrites are powered by the `$CONSOLE_APP_URL`,
`$STUDIO_APP_URL`, and `$DOCS_APP_URL` environment variables you set in Step 2.

### Local dev vs production URLs

Each Next.js app reads `NEXT_PUBLIC_BASE_PATH` from its `.env.local`:

| Environment | Value | Result |
|---|---|---|
| Local (`.env.local`) | *(empty)* | `localhost:3001/` |
| Production (Vercel env) | `/console` | `mlebotics.com/console/` |

This means local dev continues to work unchanged — no subpath prefix needed.

---

## Stack

- **Turborepo 2** — monorepo task orchestration
- **pnpm** — package manager with workspaces
- **Next.js 15** — App Router, React Server Components
- **Astro 4** — island architecture for marketing
- **tRPC v11** — end-to-end typesafe API
- **Prisma** — database ORM (Postgres)
- **Tailwind CSS** — utility-first styling
- **TypeScript** — strict mode across all packages