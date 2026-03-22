import type { EdgeAgentConfig, EdgeAgentState, LocalSensorReading } from './types';
import type { RobotTelemetry, RobotCommand } from '@mlebotics/robotics-agents';

/**
 * EdgeAgent — Phase 4/5 skeleton
 *
 * Runs on-device (Raspberry Pi, Jetson, embedded Linux). Handles:
 *   - Connecting to the MLEbotics platform via the cloud robot-agent
 *   - Collecting local sensor readings and packaging them as telemetry
 *   - Receiving RobotCommands from the platform and dispatching to hardware drivers
 *
 * Full implementation is Phase 4–5.
 */
export class EdgeAgent {
  private config: EdgeAgentConfig;
  private state: EdgeAgentState = 'booting';

  constructor(config: EdgeAgentConfig) {
    this.config = config;
  }

  getState(): EdgeAgentState {
    return this.state;
  }

  async start(): Promise<void> {
    // TODO: connect to platform via robot-agent WebSocket
    // TODO: start heartbeat loop (this.config.heartbeatIntervalMs)
    // TODO: register local hardware drivers
    throw new Error('EdgeAgent.start() not yet implemented');
  }

  async stop(): Promise<void> {
    // TODO: graceful shutdown — flush telemetry, close connections
    this.state = 'disconnected';
  }

  async sendTelemetry(readings: LocalSensorReading[]): Promise<void> {
    // TODO: package readings as RobotTelemetry and push to platform
    throw new Error('EdgeAgent.sendTelemetry() not yet implemented');
  }

  async handleCommand(command: RobotCommand): Promise<void> {
    // TODO: route command to appropriate hardware driver based on command.type
    throw new Error('EdgeAgent.handleCommand() not yet implemented');
  }
}
