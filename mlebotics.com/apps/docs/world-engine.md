# World Engine

## Overview

The `WorldEngine` manages the real-time state of a single World — the spatial and logical container for all entities and data streams. Each organization has one World per session in Phase 5.

## Concepts

- **World** — top-level container with an ID, name, and org context
- **Entity** — any object existing inside a World (robot, sensor, agent, zone, virtual object)
- **Stream** — a live data channel attached to an entity (telemetry, video, sensor, etc.)

## Entity Types

```
robot | sensor | actuator | zone | agent | virtual
```

## Stream Types

```
telemetry | video | audio | sensor | event | custom
```

## API

### Initialise the engine

```typescript
const rt = PlatformRuntime.create('org-123')
rt.world.init({
  id:        'world-1',
  name:      'Warehouse Floor A',
  slug:      'warehouse-floor-a',
  orgId:     'org-123',
  createdAt: new Date(),
  updatedAt: new Date(),
})
```

### Entity lifecycle

```typescript
// Create or update an entity (upsert)
const robot = rt.world.upsertEntity({
  id:   'robot-1',
  type: 'robot',
  name: 'AMR-001',
  metadata: { model: 'MobileBot 3', firmware: '2.1.0' },
  position: { x: 12.5, y: 0, z: 3.0 },
})

// Retrieve
const entity = rt.world.getEntity('robot-1')

// List all
const entities = rt.world.listEntities()

// Remove (also removes attached streams)
rt.world.removeEntity('robot-1')
```

### Stream lifecycle

```typescript
// Start a stream
rt.world.startStream({
  id:      'stream-1',
  entityId: 'robot-1',
  worldId:  'world-1',
  name:    'Telemetry',
  type:    'telemetry',
  schema:  { battery: 'number', speed: 'number' },
  active:  false,
})

// Stop a stream
rt.world.stopStream('stream-1')
```

## Events Emitted

- `world.entity.created` — on first upsert of an entity
- `world.entity.updated` — on subsequent upserts
- `world.entity.removed` — on entity deletion
- `world.stream.started` — when a stream is started
- `world.stream.stopped` — when a stream is stopped

## Phase 6 Notes

- Persist entity + stream state to the database via Prisma
- Support multi-world per organisation
- Add entity change history and event replay
