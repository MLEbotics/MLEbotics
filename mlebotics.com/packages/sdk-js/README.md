# packages/sdk-js

**JavaScript/TypeScript SDK for the MLEbotics Platform API (Phase 5 skeleton)**

`@mlebotics/sdk-js` is the official client SDK for external integrations. Use it to build companion apps, robot firmware bridges, partner integrations, and automation scripts that talk to the MLEbotics platform.

## Status

> ⚠️ **Skeleton only.** Full implementation is planned for Phase 5 of the MLEbotics roadmap.

## Installation

```bash
# Once published
npm install @mlebotics/sdk-js

# Within the monorepo
pnpm add @mlebotics/sdk-js
```

## Usage

```typescript
import { PlatformClient } from '@mlebotics/sdk-js';

const client = new PlatformClient({
  baseUrl: 'https://app.mlebotics.com/api',
  apiKey: process.env.MLEBOTICS_API_KEY,
});

// Health check
const health = await client.ping();

// User info
const me = await client.getCurrentUser();

// List organizations
const orgs = await client.listOrganizations();
```

## Auth Modes

| Mode | When to use |
|---|---|
| `apiKey` | Server-to-server, robot firmware, CI scripts |
| `token` | User-session browser/mobile apps |

## API

### `new PlatformClient(options)`

| Option | Type | Required | Description |
|---|---|---|---|
| `baseUrl` | `string` | ✅ | Platform API base URL |
| `apiKey` | `string` | — | API key for server auth |
| `token` | `string` | — | Bearer token for user auth |

### Methods (Phase 5 stubs)

| Method | Returns | Description |
|---|---|---|
| `ping()` | `HealthResponse` | Check API availability |
| `getCurrentUser()` | `UserProfile` | Get the authenticated user |
| `listOrganizations()` | `Organization[]` | List orgs the user belongs to |
| `getOrganization(slug)` | `Organization` | Get a specific org by slug |

## Phase 5 TODOs

- [ ] Wire all methods to the tRPC HTTP client
- [ ] Add Robot, Workflow, and Plugin resource methods
- [ ] Add WebSocket support for real-time telemetry subscriptions
- [ ] Add pagination helpers
- [ ] Publish to npm as `@mlebotics/sdk-js`
- [ ] Write integration tests
