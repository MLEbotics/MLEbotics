// robotics/adapters/ros2-bridge/src/adapter.ts
// Phase 4 — ROS 2 Bridge Adapter stub
// TODO Phase 4: implement using rclnodejs

import type { ROS2AdapterConfig, BridgeState } from './types'

export class ROS2BridgeAdapter {
  private config: ROS2AdapterConfig
  private state: BridgeState = 'disconnected'

  constructor(config: ROS2AdapterConfig) {
    this.config = config
  }

  getState(): BridgeState {
    return this.state
  }

  // TODO Phase 4: initialize rclnodejs, create node, subscribe to topics
  async connect(): Promise<void> {
    this.state = 'connecting'
    console.log(`[ROS2Bridge] Connecting — domain=${this.config.ros2DomainId}, ns=${this.config.ros2Namespace}`)
    // TODO: await rclnodejs.init(); create node; subscribe
    throw new Error('ROS2BridgeAdapter.connect() not yet implemented — Phase 4')
  }

  // TODO Phase 4: destroy node, clean up subscriptions
  async disconnect(): Promise<void> {
    this.state = 'disconnected'
    console.log('[ROS2Bridge] Disconnected')
  }
}
