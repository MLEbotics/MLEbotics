import type { RobotAgent, RobotTelemetry, RobotCommand } from '@mlebotics/robotics-agents';

export interface EdgeAgentConfig {
  /** Unique agent identifier — must match the platform RobotAgent.id */
  agentId: string;
  /** Platform API base URL for phoning home */
  platformUrl: string;
  /** API key for authenticating with the platform */
  apiKey: string;
  /** How often to send telemetry heartbeats (ms) */
  heartbeatIntervalMs?: number;
}

export interface LocalSensorReading {
  sensorId: string;
  value: number | string | boolean;
  unit?: string;
  timestamp: Date;
}

export type EdgeAgentState = 'booting' | 'connected' | 'disconnected' | 'error';

export type { RobotAgent, RobotTelemetry, RobotCommand };
