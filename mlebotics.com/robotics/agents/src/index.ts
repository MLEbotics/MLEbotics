// robotics/agents/src/index.ts
// Phase 4 — robot agent entry point (skeleton only)
// TODO Phase 4: implement AgentRuntime class, command dispatcher, telemetry emitter

export type {
  RobotAgent, RobotType, RobotStatus, RobotCapability,
  RobotCommand, CommandStatus,
  RobotTelemetry,
} from './types'

/**
 * AgentRuntime — placeholder for the robot agent execution environment.
 * Will be implemented in Phase 4 (robot control).
 */
export class AgentRuntime {
  // TODO Phase 4: constructor(config: AgentRuntimeConfig)
  // TODO Phase 4: start(): Promise<void>
  // TODO Phase 4: stop(): Promise<void>
  // TODO Phase 4: dispatch(command: RobotCommand): Promise<void>
  // TODO Phase 4: on(event: 'telemetry', handler: (t: RobotTelemetry) => void): void
}
