// platform/automation-engine/executor.ts
// WorkflowExecutor — Phase 5 sequential step runner.
// Real async step dispatch + run lifecycle state machine.
// Sandboxing, persistence, and distributed execution are Phase 6.

import type { IEventBus } from '../event-bus/types'
import type { Workflow, WorkflowRun, Step, StepRun } from '../automation/types'
import type { ID } from '../shared/types'

// ── Step execution context ──────────────────────────────────────────────────

export interface RunContext {
  runId:      ID
  orgId:      ID
  triggeredBy: string
  variables:  Record<string, unknown>
}

export interface StepOutput {
  success: boolean
  result:  Record<string, unknown>
  error?:  string
}

// ── Built-in step handlers ───────────────────────────────────────────────────

async function handleDelay(step: Step): Promise<StepOutput> {
  const ms = Number(step.config['ms'] ?? (Number(step.config['seconds'] ?? 0) * 1000))
  if (ms > 0) await new Promise<void>(resolve => setTimeout(resolve, ms))
  return { success: true, result: { waited: ms } }
}

function handleCondition(step: Step, ctx: RunContext): StepOutput {
  // Phase 5: evaluate config.expression as a variable lookup or literal boolean
  const expr = step.config['expression'] as string | undefined
  if (!expr) return { success: true, result: { matched: true } }

  const value = ctx.variables[expr]
  const matched = value !== undefined ? Boolean(value) : true
  return { success: true, result: { matched, expression: expr } }
}

function handleNotification(step: Step, ctx: RunContext): StepOutput {
  const message = String(step.config['message'] ?? `Workflow step: ${step.name}`)
  // In Phase 5 notifications go to the console; Phase 6 will wire real channels
  console.info(`[notification] org=${ctx.orgId} run=${ctx.runId} | ${message}`)
  return { success: true, result: { delivered: true, message } }
}

function handleStub(step: Step): StepOutput {
  // robot_command, api_call, agent_invoke, plugin_action — stubs for Phase 5
  console.info(`[executor] stub step '${step.type}': ${step.name}`)
  return { success: true, result: { stub: true, stepType: step.type } }
}

async function executeStep(step: Step, ctx: RunContext): Promise<StepOutput> {
  switch (step.type) {
    case 'delay':        return handleDelay(step)
    case 'condition':    return handleCondition(step, ctx)
    case 'notification': return handleNotification(step, ctx)
    default:             return handleStub(step)
  }
}

// ── WorkflowExecutor ─────────────────────────────────────────────────────────

export class WorkflowExecutor {
  private readonly _bus: IEventBus
  private readonly _cancelledRuns = new Set<ID>()

  constructor(bus: IEventBus) {
    this._bus = bus
  }

  cancel(runId: ID): void {
    this._cancelledRuns.add(runId)
  }

  async execute(workflow: Workflow, ctx: RunContext): Promise<WorkflowRun> {
    const runId    = ctx.runId
    const now      = new Date()
    const stepRuns: StepRun[] = []

    const run: WorkflowRun = {
      id:         runId,
      workflowId: workflow.id,
      status:     'running',
      startedAt:  now,
      stepRuns,
    }

    this._bus.emit({
      type:           'automation.workflow.started',
      organizationId: ctx.orgId,
      source:         'automation-engine',
      payload:        { runId, workflowId: workflow.id, triggeredBy: ctx.triggeredBy },
    })

    // Sort steps by order field
    const steps = [...workflow.steps].sort((a, b) => a.order - b.order)

    for (const step of steps) {
      // Check for cancellation before each step
      if (this._cancelledRuns.has(runId)) {
        run.status     = 'cancelled'
        run.finishedAt = new Date()
        this._cancelledRuns.delete(runId)
        return run
      }

      const stepRunId = crypto.randomUUID()
      const stepStart = new Date()

      this._bus.emit({
        type:           'automation.step.started',
        organizationId: ctx.orgId,
        source:         'automation-engine',
        payload:        { runId, stepId: step.id, stepRunId },
      })

      let output: StepOutput
      try {
        output = await executeStep(step, ctx)
      } catch (err) {
        output = { success: false, result: {}, error: String(err) }
      }

      const stepRun: StepRun = {
        id:         stepRunId,
        stepId:     step.id,
        runId,
        status:     output.success ? 'success' : 'failed',
        startedAt:  stepStart,
        finishedAt: new Date(),
        output:     output.result,
        error:      output.error,
      }
      stepRuns.push(stepRun)

      // Propagate variables from step output for subsequent steps
      if (output.success) {
        Object.assign(ctx.variables, output.result)
      }

      this._bus.emit({
        type:           output.success ? 'automation.step.completed' : 'automation.step.failed',
        organizationId: ctx.orgId,
        source:         'automation-engine',
        payload:        stepRun,
      })

      // On failure, check for an explicit fallback step; otherwise abort
      if (!output.success && !step.onFailure) {
        run.status     = 'failed'
        run.finishedAt = new Date()

        this._bus.emit({
          type:           'automation.workflow.failed',
          organizationId: ctx.orgId,
          source:         'automation-engine',
          payload:        { runId, failedStepId: step.id, error: output.error },
        })

        return run
      }
    }

    run.status     = 'success'
    run.finishedAt = new Date()

    this._bus.emit({
      type:           'automation.workflow.completed',
      organizationId: ctx.orgId,
      source:         'automation-engine',
      payload:        { runId, workflowId: workflow.id },
    })

    return run
  }
}
