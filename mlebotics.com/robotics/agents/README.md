# robotics/agents

**Phase 4 — Robot Agents (Skeleton)**

This package defines the runtime interface for robot agents. A robot agent is the software process that:
- Receives commands from the platform (via the adapter layer)
- Maintains live robot state
- Emits telemetry back to the World Engine

## Status

> ⚠️ **Skeleton only.** Full implementation will happen in Phase 4 of the MLEbotics roadmap.

## Structure

```
src/
  types.ts      ← RobotAgent, RobotCommand, RobotTelemetry interfaces
  index.ts      ← AgentRuntime class (stub)
```

## Interfaces defined

| Interface       | Description |
|---|---|
| `RobotAgent`    | Physical or virtual robot registered in the platform |
| `RobotCommand`  | Instruction sent to a robot |
| `RobotTelemetry`| Data emitted by a robot at runtime |
| `AgentRuntime`  | Execution environment (stub — Phase 4) |

## Phase 4 TODOs

- [ ] Implement `AgentRuntime` class
- [ ] WebSocket telemetry channel
- [ ] Command queue with retry logic
- [ ] Health-check loop
- [ ] Integration with `robotics/adapters` layer
