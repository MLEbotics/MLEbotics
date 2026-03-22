# robotics/adapters/ros2-bridge

**Phase 4 — ROS 2 Bridge Adapter (Skeleton)**

Connects ROS 2 robots to the MLEbotics platform by translating ROS 2 topics, services, and actions into the platform's unified command/telemetry protocol.

## Status

> ⚠️ **Skeleton only.** Full implementation is planned for Phase 4 of the MLEbotics roadmap.

## What This Adapter Does

| Direction | From → To | Description |
|---|---|---|
| Inbound | ROS 2 topic → Platform stream | Telemetry, sensor data, robot state |
| Outbound | Platform command → ROS 2 service | Drive, arm control, navigation goals |
| Events | ROS 2 action feedback → Platform event | Long-running task progress |

## Config Schema

```json
{
  "ros2_domain_id": 0,
  "ros2_namespace": "/robot1",
  "platform_robot_id": "<MLEbotics robot UUID>",
  "telemetry_topics": ["/odom", "/battery_state", "/scan"],
  "command_services": ["/cmd_vel", "/gripper_control"],
  "heartbeat_interval_ms": 5000
}
```

## Structure

```
src/
  types.ts      ← ROS2AdapterConfig, ROS2TopicMap interfaces
  adapter.ts    ← ROS2BridgeAdapter class stub
  index.ts      ← Entry point
```

## Phase 4 TODOs

- [ ] Connect to ROS 2 via `rclnodejs`
- [ ] Subscribe to configured topics and push to Platform stream API
- [ ] Translate Platform commands to ROS 2 service calls
- [ ] Implement heartbeat and reconnection logic
- [ ] Add TLS + auth token support for cloud ↔ edge tunneling
