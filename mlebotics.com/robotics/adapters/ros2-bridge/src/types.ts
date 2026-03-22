// robotics/adapters/ros2-bridge/src/types.ts
// Phase 4 — ROS 2 Bridge type definitions

/**
 * Configuration for the ROS 2 Bridge adapter.
 * Loaded at startup from config file or environment variables.
 */
export interface ROS2AdapterConfig {
  /** ROS 2 DDS domain ID (default: 0) */
  ros2DomainId: number
  /** ROS 2 node namespace */
  ros2Namespace: string
  /** MLEbotics robot UUID this adapter represents */
  platformRobotId: string
  /** List of ROS 2 topics to subscribe and forward as platform streams */
  telemetryTopics: string[]
  /** List of ROS 2 services to expose as platform commands */
  commandServices: string[]
  /** Heartbeat interval in milliseconds */
  heartbeatIntervalMs: number
}

/**
 * Maps a ROS 2 topic to a platform stream name.
 */
export interface ROS2TopicMap {
  ros2Topic: string
  platformStreamName: string
  /** Optional transform function name (applied before forwarding) */
  transform?: string
}

/**
 * Connection state of the ROS 2 bridge.
 */
export type BridgeState =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'error'
  | 'reconnecting'
