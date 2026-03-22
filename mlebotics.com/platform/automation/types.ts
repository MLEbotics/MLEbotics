// platform/automation/types.ts
// Phase 3 — Automation Engine TypeScript interfaces
// No runtime logic here — structure only.

/** A Workflow is a named, reusable automation sequence. */
export interface Workflow {
  id:          string
  name:        string
  description?: string
  orgId:       string
  status:      WorkflowStatus
  trigger:     Trigger
  steps:       Step[]
  createdAt:   Date
  updatedAt:   Date
}

export type WorkflowStatus = 'draft' | 'active' | 'paused' | 'archived'

/**
 * A Trigger defines when a Workflow is activated.
 */
export interface Trigger {
  type:   TriggerType
  config: Record<string, unknown>
}

export type TriggerType =
  | 'schedule'    // cron-based
  | 'event'       // fired by a platform event
  | 'webhook'     // HTTP call
  | 'manual'      // user-initiated
  | 'condition'   // state-based threshold

/**
 * A Step is a single unit of execution within a Workflow.
 * Steps are ordered and can branch on output.
 */
export interface Step {
  id:         string
  workflowId: string
  order:      number
  type:       StepType
  name:       string
  config:     Record<string, unknown>
  onSuccess?: string   // next step id
  onFailure?: string   // fallback step id
}

export type StepType =
  | 'robot_command'    // send a command to a robot
  | 'api_call'         // call an external HTTP endpoint
  | 'condition'        // if/else branch
  | 'delay'            // wait N seconds
  | 'agent_invoke'     // trigger an AI agent
  | 'notification'     // send alert / message
  | 'plugin_action'    // invoke a plugin step
  | 'custom'

/** A WorkflowRun is a single execution instance of a Workflow. */
export interface WorkflowRun {
  id:         string
  workflowId: string
  status:     RunStatus
  startedAt:  Date
  finishedAt?: Date
  stepRuns:   StepRun[]
}

export type RunStatus = 'queued' | 'running' | 'success' | 'failed' | 'cancelled'

export interface StepRun {
  id:         string
  stepId:     string
  runId:      string
  status:     RunStatus
  startedAt:  Date
  finishedAt?: Date
  output:     Record<string, unknown>
  error?:     string
}
