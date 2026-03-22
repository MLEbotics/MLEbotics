# robotics/adapters/mqtt-bridge

**Phase 4 — MQTT Bridge Adapter (Skeleton)**

Connects MQTT-capable devices, robots, and microcontrollers to the MLEbotics platform by subscribing to configured MQTT topics and translating messages to platform streams and commands.

## Status

> ⚠️ **Skeleton only.** Full implementation is planned for Phase 4 of the MLEbotics roadmap.

## What This Adapter Does

| Direction | From → To | Description |
|---|---|---|
| Inbound | MQTT topic → Platform stream | Sensor readings, robot state, telemetry |
| Outbound | Platform command → MQTT publish | Motor control, actuator state, setpoints |

## Config Schema

```json
{
  "broker_url": "mqtt://broker.local:1883",
  "client_id": "mlebotics-adapter-001",
  "platform_robot_id": "<MLEbotics robot UUID>",
  "username": "",
  "password": "",
  "tls": false,
  "subscribe_topics": ["robot/+/state", "robot/+/telemetry"],
  "publish_topic_prefix": "robot/commands/",
  "qos": 1
}
```

## Structure

```
src/
  types.ts      ← MQTTAdapterConfig, MQTTTopicMap interfaces
  adapter.ts    ← MQTTBridgeAdapter class stub
  index.ts      ← Entry point
```

## Phase 4 TODOs

- [ ] Connect to MQTT broker via `mqtt.js`
- [ ] Subscribe to configured topics, parse and forward to Platform stream API
- [ ] Listen for Platform commands and publish to MQTT
- [ ] Handle reconnection with exponential backoff
- [ ] Add TLS certificate support
- [ ] Support QoS levels 0, 1, 2
