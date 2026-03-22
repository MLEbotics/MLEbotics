import type { MQTTAdapterConfig, BridgeState } from './types';

/**
 * MQTTBridgeAdapter — Phase 4 skeleton
 *
 * Subscribes to MQTT topics and translates messages to/from the MLEbotics
 * platform stream API. Full implementation is Phase 4.
 */
export class MQTTBridgeAdapter {
  private config: MQTTAdapterConfig;
  private state: BridgeState = 'disconnected';

  constructor(config: MQTTAdapterConfig) {
    this.config = config;
  }

  getState(): BridgeState {
    return this.state;
  }

  async connect(): Promise<void> {
    // TODO: connect via mqtt.js
    // TODO: subscribe to this.config.subscribeTopics
    // TODO: set up message handlers to forward to platform streams
    throw new Error('MQTTBridgeAdapter.connect() not yet implemented');
  }

  async disconnect(): Promise<void> {
    // TODO: unsubscribe and end MQTT client
    this.state = 'disconnected';
  }

  async sendCommand(topic: string, payload: unknown): Promise<void> {
    // TODO: serialize payload and publish to broker
    throw new Error('MQTTBridgeAdapter.sendCommand() not yet implemented');
  }
}
