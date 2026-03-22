import type { RobotAgentConfig, CloudAgentState, CommandResult } from './types';
import type { RobotAgent, RobotCommand, RobotTelemetry } from '@mlebotics/robotics-agents';

/**
 * RobotAgentCloud — Phase 4/5 skeleton
 *
 * Cloud-side representative of a physical robot. Runs in the platform backend
 * (not on-device). Responsibilities:
 *   - Maintain authoritative robot state in the database
 *   - Receive telemetry from the EdgeAgent, persist and emit platform events
 *   - Accept RobotCommands from the AutomationEngine or operator UI
 *   - Dispatch commands to the connected EdgeAgent and track command lifecycle
 *
 * Full implementation is Phase 4–5.
 */
export class RobotAgentCloud {
  private config: RobotAgentConfig;
  private state: CloudAgentState = 'offline';
  private commandQueue: RobotCommand[] = [];

  constructor(config: RobotAgentConfig) {
    this.config = config;
  }

  getState(): CloudAgentState {
    return this.state;
  }

  async getRobotProfile(): Promise<RobotAgent> {
    // TODO: load RobotAgent record from db by this.config.robotId
    throw new Error('RobotAgentCloud.getRobotProfile() not yet implemented');
  }

  async onTelemetryReceived(telemetry: RobotTelemetry): Promise<void> {
    // TODO: persist telemetry, update robot lastSeenAt
    // TODO: emit robotics.robot.telemetry via EventBus
    throw new Error('RobotAgentCloud.onTelemetryReceived() not yet implemented');
  }

  async dispatchCommand(command: RobotCommand): Promise<void> {
    // TODO: validate against robot capabilities
    // TODO: push to commandQueue, emit robotics.command.sent
    // TODO: forward to EdgeAgent connection
    throw new Error('RobotAgentCloud.dispatchCommand() not yet implemented');
  }

  async onCommandResult(result: CommandResult): Promise<void> {
    // TODO: update command status in db
    // TODO: emit robotics.command.completed or robotics.command.failed
    throw new Error('RobotAgentCloud.onCommandResult() not yet implemented');
  }

  async onEdgeConnected(): Promise<void> {
    // TODO: update robot status to 'online', emit robotics.robot.connected
    this.state = 'idle';
  }

  async onEdgeDisconnected(): Promise<void> {
    // TODO: update robot status to 'offline', emit robotics.robot.disconnected
    this.state = 'offline';
  }
}
