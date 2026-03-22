import type { RobotAgent, RobotStatus, RobotCommand, CommandStatus } from '@mlebotics/robotics-agents';

export interface RobotAgentConfig {
  /** Platform robot UUID */
  robotId: string;
  /** Organization the robot belongs to */
  orgId: string;
  /** Maximum concurrent commands in the dispatch queue */
  maxQueueDepth?: number;
}

export interface CommandResult {
  commandId: string;
  status: CommandStatus;
  output?: Record<string, unknown>;
  error?: string;
  completedAt: Date;
}

export type CloudAgentState = 'idle' | 'busy' | 'offline' | 'error';

export type { RobotAgent, RobotStatus, RobotCommand };
