export type BridgeState =
  | 'disconnected'
  | 'connecting'
  | 'connected'
  | 'reconnecting'
  | 'error';

export interface MQTTTopicMap {
  /** MQTT topic pattern (may include wildcards like + or #) */
  topic: string;
  /** Corresponding platform stream name for this data */
  platformStreamName: string;
  /** Optional transform function name to apply on raw payload */
  transform?: string;
}

export interface MQTTAdapterConfig {
  /** MQTT broker connection URL, e.g. mqtt://broker.local:1883 */
  brokerUrl: string;
  /** Unique MQTT client identifier */
  clientId: string;
  /** MLEbotics platform Robot UUID this adapter represents */
  platformRobotId: string;
  /** Optional broker username */
  username?: string;
  /** Optional broker password */
  password?: string;
  /** Enable TLS/SSL connection */
  tls?: boolean;
  /** Topics to subscribe for inbound telemetry/state */
  subscribeTopics: MQTTTopicMap[];
  /** Topic prefix for outbound platform→device commands */
  publishTopicPrefix: string;
  /** MQTT QoS level: 0 (at most once), 1 (at least once), 2 (exactly once) */
  qos?: 0 | 1 | 2;
}
