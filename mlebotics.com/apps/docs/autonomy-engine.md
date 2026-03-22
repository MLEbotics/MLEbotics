# Autonomy Engine

**Phase 5 — AI Decision Layer (Planned)**

The Autonomy Engine is the core AI decision system that allows robots and agents to operate with minimal human intervention. It evaluates real-world state, applies policies, and issues commands back through the platform.

---

## Architecture Overview

```
Platform World State
       │
       ▼
┌─────────────────────────────┐
│       Autonomy Engine        │
│  ┌──────────┐ ┌──────────┐  │
│  │  Planner │ │ Executor │  │
│  └────┬─────┘ └────┬─────┘  │
│       │            │        │
│  ┌────▼────────────▼──────┐ │
│  │     Safety Controller  │ │
│  └────────────────────────┘ │
└─────────────────────────────┘
       │
       ▼
Robot Commands → robotics/adapters/*
```

---

## Components

### Planner
- Ingests world state from `platform/world/types.ts → World` model
- Runs task decomposition against active `Workflow` (see `platform/automation/types.ts`)
- Emits ordered step sequences for the Executor

### Executor
- Iterates planned steps
- Dispatches commands to robots via `@mlebotics/robotics-agents → AgentRuntime`
- Reports step status back as `StepRun` updates

### Safety Controller
- Validates every command before dispatch
- Enforces configurable policy rules (geofences, velocity limits, battery thresholds)
- Can halt the entire autonomy loop on policy violation

---

## Integration Points

| Platform package | Used by |
|---|---|
| `platform/world` | Planner — reads entity state and world context |
| `platform/automation` | Planner — activates and tracks Workflow runs |
| `robotics/agents` | Executor — issues RobotCommand to AgentRuntime |
| `robotics/adapters/*` | Executor — sends commands to physical hardware |

---

## Phase 5 TODOs

<!-- TODO: implement Planner with LLM-based task decomposition -->
<!-- TODO: implement Executor with retry + timeout logic -->
<!-- TODO: implement Safety Controller with configurable policy rules -->
<!-- TODO: expose autonomy session REST/tRPC endpoints in packages/api -->
<!-- TODO: add autonomy status dashboard route in apps/console -->
<!-- TODO: write unit tests for safety policy enforcement -->

---

## Safety Design Principles

- **Fail-safe by default** — any unrecognized state triggers a stop command
- **Policy-first** — no command is dispatched without safety controller approval
- **Audit trail** — all decisions are logged as `AuditEvent` (see `platform/shared/types.ts`)
- **Human-in-the-loop** — Phase 5 ships with an override UI for operators
