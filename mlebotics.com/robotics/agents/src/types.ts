// robotics/agents/src/types.ts
// Phase 4 — Robot agent interface definitions

/**
 * A RobotAgent is the software representation of a physical or simulated robot.
 * It maintains state, receives commands, and emits telemetry.
 *
 * Full implementation planned for Phase 4 (robot control) release.
 */
export interface RobotAgent {
  id:           string
  name:         string
  type:         RobotType
  status:       RobotStatus
  orgId:        string
  worldId?:     string    // which World this robot belongs to (Phase 3 link)
  adapterId:    string    // which adapter protocol this robot uses
  capabilities: RobotCapability[]
  metadata:     Record<string, unknown>
  lastSeenAt?:  Date
  createdAt:    Date
}

export type RobotType =
  | 'wheeled'
  | 'arm'
  | 'drone'
  | 'humanoid'
  | 'stationary'
  | 'virtual'
  | 'custom'

export type RobotStatus =
  | 'online'
  | 'offline'
  | 'idle'
  | 'busy'
  | 'error'
  | 'charging'
  | 'maintenance'

export type RobotCapability =
  | 'movement'
  | 'manipulation'
  | 'vision'
  | 'speech'
  | 'telemetry'
  | 'navigation'
  | 'mapping'

/**
 * A RobotCommand is an instruction sent to a RobotAgent.
 * Commands are queued, validated, and dispatched via the adapter layer.
 */
export interface RobotCommand {
  id:        string
  robotId:   string
  type:      string          // adapter-specific command type
  params:    Record<string, unknown>
  issuedBy:  string          // userId
  issuedAt:  Date
  status:    CommandStatus
}

export type CommandStatus = 'queued' | 'dispatched' | 'executing' | 'success' | 'failed' | 'cancelled'

/**
 * Telemetry emitted by a robot at runtime.
 */
export interface RobotTelemetry {
  robotId:   string
  timestamp: Date
  data:      Record<string, unknown>
}
