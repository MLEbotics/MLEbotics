# Automation Engine

## Overview

The `AutomationEngine` manages workflow definitions, triggers execution runs, and tracks run state. It is backed by a `WorkflowExecutor` that runs steps sequentially, emitting events at each stage transition.

## Concepts

- **Workflow** — a named sequence of steps with a trigger and a status (`draft | active | paused | archived`)
- **Trigger** — defines when a workflow fires (`manual | schedule | event | webhook | condition`)
- **Step** — a single unit of execution within a workflow
- **WorkflowRun** — a single execution instance with a run status and step run history

## Step Types

| Type | Phase 5 Behaviour |
| --- | --- |
| `delay` | Waits for `config.ms` milliseconds |
| `condition` | Evaluates `config.expression` against run variables |
| `notification` | Logs `config.message` to console (Phase 6: real channels) |
| `robot_command` | Stub — returns success |
| `api_call` | Stub — returns success |
| `agent_invoke` | Stub — returns success |
| `plugin_action` | Stub — returns success |
| `custom` | Stub — returns success |

## API

### Register + trigger a workflow

```typescript
const rt = PlatformRuntime.create('org-123')

const wf = rt.automation.registerWorkflow({
  id:      'wf-1',
  name:    'Morning Alert',
  orgId:   'org-123',
  status:  'active',
  trigger: { type: 'manual', config: {} },
  steps: [
    {
      id: 'step-1', workflowId: 'wf-1', order: 1,
      type: 'notification', name: 'Notify',
      config: { message: 'Good morning!' },
    },
  ],
  createdAt: new Date(),
  updatedAt: new Date(),
})

// Trigger returns immediately with a queued run
const run = await rt.automation.triggerWorkflow('wf-1', 'user-123')
console.log(run.id) // use this to poll status
```

### Poll run status

```typescript
const status = rt.automation.getRunStatus(run.id)
// status.status: 'queued' | 'running' | 'success' | 'failed' | 'cancelled'
```

### Cancel a run

```typescript
await rt.automation.cancelRun(run.id)
```

## Run Lifecycle

```
queued → running → success
               → failed      (step failed with no fallback)
               → cancelled   (cancel() called mid-run)
```

## Events Emitted

- `automation.workflow.started` — when a run begins
- `automation.step.started` — before each step executes
- `automation.step.completed` — after a step succeeds
- `automation.step.failed` — after a step fails
- `automation.workflow.completed` — when all steps succeed
- `automation.workflow.failed` — when a step fails and has no fallback

## tRPC Procedures

All procedures are under `workflow.*` in the API router:

- `workflow.list` — list registered workflows
- `workflow.create` — create a new draft workflow
- `workflow.trigger` — trigger a workflow run
- `workflow.getRun` — poll a run by ID
- `workflow.listRuns` — list runs (optionally filtered by workflowId)
- `workflow.cancel` — cancel a running or queued run

## Phase 6 Notes

- Persist workflows and runs to Prisma
- Add schedule-based trigger (cron runner)
- Add parallel step execution
- Add real step handlers for `robot_command` and `api_call`
