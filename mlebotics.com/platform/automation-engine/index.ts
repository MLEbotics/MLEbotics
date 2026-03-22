// platform/automation-engine/index.ts
// AutomationEngine — Phase 5 implementation.
// Manages workflow registration, manual triggering, run tracking, and cancellation.
// Connects to WorkflowExecutor for step-level execution.

import type { IEventBus } from '../event-bus/types'
import type { Workflow, WorkflowRun, Trigger } from '../automation/types'
import type { ID } from '../shared/types'
import { WorkflowExecutor } from './executor'
export type { RunContext, StepOutput } from './executor'

export class AutomationEngine {
  private readonly _bus:       IEventBus
  private readonly _executor:  WorkflowExecutor

  // In-memory registries — persistence is Phase 6
  private readonly _workflows = new Map<ID, Workflow>()
  private readonly _runs      = new Map<ID, WorkflowRun>()

  constructor(bus: IEventBus) {
    this._bus      = bus
    this._executor = new WorkflowExecutor(bus)
  }

  // ── Workflow registry ───────────────────────────────────────────────────────

  registerWorkflow(workflow: Workflow): Workflow {
    this._workflows.set(workflow.id, workflow)
    return workflow
  }

  listWorkflows(): Workflow[] {
    return Array.from(this._workflows.values())
  }

  getWorkflow(workflowId: ID): Workflow {
    const wf = this._workflows.get(workflowId)
    if (!wf) throw new Error(`Workflow not found: ${workflowId}`)
    return wf
  }

  // ── Run management ──────────────────────────────────────────────────────────

  async triggerWorkflow(workflowId: ID, triggeredBy: string): Promise<WorkflowRun> {
    const workflow = this.getWorkflow(workflowId)
    const runId    = crypto.randomUUID()
    const orgId    = workflow.orgId

    // Optimistically store a queued run before the executor starts
    const queued: WorkflowRun = {
      id:         runId,
      workflowId: workflow.id,
      status:     'queued',
      startedAt:  new Date(),
      stepRuns:   [],
    }
    this._runs.set(runId, queued)

    // Execute asynchronously — fire-and-forget so the caller gets the run ID
    // immediately. Call sites that need completion should poll getRunStatus().
    const resultPromise = this._executor.execute(workflow, {
      runId,
      orgId,
      triggeredBy,
      variables: {},
    })

    resultPromise
      .then(completed => { this._runs.set(runId, completed) })
      .catch(err => {
        this._runs.set(runId, {
          ...queued,
          status:     'failed',
          finishedAt: new Date(),
          stepRuns:   [],
        })
        this._bus.emit({
          type:           'system.error',
          organizationId: orgId,
          source:         'automation-engine',
          payload:        { runId, error: String(err) },
        })
      })

    return queued
  }

  async cancelRun(runId: ID): Promise<void> {
    const run = this._runs.get(runId)
    if (!run) throw new Error(`Run not found: ${runId}`)
    if (run.status !== 'running' && run.status !== 'queued') return

    // Signal the executor to stop after the current step
    this._executor.cancel(runId)

    // Optimistically update the stored run status
    this._runs.set(runId, { ...run, status: 'cancelled', finishedAt: new Date() })
  }

  getRunStatus(runId: ID): WorkflowRun {
    const run = this._runs.get(runId)
    if (!run) throw new Error(`Run not found: ${runId}`)
    return run
  }

  listRuns(workflowId?: ID): WorkflowRun[] {
    const all = Array.from(this._runs.values())
    return workflowId
      ? all.filter(r => r.workflowId === workflowId)
      : all
  }

  // ── Triggers ────────────────────────────────────────────────────────────────

  listTriggersForWorkflow(workflowId: ID): Trigger[] {
    const workflow = this.getWorkflow(workflowId)
    return [workflow.trigger]
  }
}

export type { Workflow, WorkflowRun, Trigger }
