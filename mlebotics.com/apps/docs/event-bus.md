# Event Bus

## Overview

The MLEbotics Event Bus is the central nervous system of the platform. It provides a typed, in-memory publish/subscribe channel that all engines use to communicate without direct coupling.

## Architecture

The event bus is implemented as `InMemoryEventBus`, which satisfies the `IEventBus` interface. All engines receive the bus via constructor injection — they never create their own instance.

**Dependency flow:**

```
PlatformRuntime
  └── InMemoryEventBus (shared singleton)
        ├── WorldEngine (injected)
        ├── AutomationEngine (injected)
        └── PluginEngine (injected)
```

## Event Types

All 22 platform event types are union-typed as `EventType`:

- **World events** — `world.entity.created`, `world.entity.updated`, `world.entity.removed`, `world.stream.started`, `world.stream.stopped`
- **Automation events** — `automation.workflow.started`, `automation.workflow.completed`, `automation.workflow.failed`, `automation.step.started`, `automation.step.completed`, `automation.step.failed`
- **Robotics events** — `robotics.robot.connected`, `robotics.robot.disconnected`, `robotics.robot.telemetry`, `robotics.command.sent`, `robotics.command.completed`, `robotics.command.failed`
- **Plugin events** — `plugin.installed`, `plugin.uninstalled`, `plugin.error`
- **System events** — `system.error`, `system.warning`

## API

```typescript
// Subscribe to one or more event types
const sub = bus.subscribe(['world.entity.created'], (event) => {
  console.log(event.payload)
})

// Emit an event (id + timestamp auto-generated)
bus.emit({
  type:           'world.entity.created',
  organizationId: 'org-123',
  source:         'world-engine',
  payload:        entity,
})

// Unsubscribe
bus.unsubscribe(sub.id)
```

## Implementation Notes

- IDs are generated via `crypto.randomUUID()`
- Subscriptions are stored in a `Map<ID, { types, handler }>`
- Async handlers are fire-and-forget (errors are caught and logged)
- Synchronous handlers block the emit call
- Phase 6: replace with a distributed event bus (Redis Streams, NATS)
