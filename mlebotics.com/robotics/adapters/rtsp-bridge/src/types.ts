export type RTSPStreamState =
  | 'idle'
  | 'connecting'
  | 'streaming'
  | 'reconnecting'
  | 'error'
  | 'stopped';

export interface RTSPAdapterConfig {
  /** Full RTSP source URL, e.g. rtsp://192.168.1.10:554/stream */
  rtspUrl: string;
  /** MLEbotics platform Robot UUID this stream belongs to */
  platformRobotId: string;
  /** Human-readable stream name shown in the platform UI */
  streamName: string;
  /** Video codec expected from the source */
  codec?: 'h264' | 'h265' | 'mjpeg' | 'auto';
  /** Ms to wait before attempting reconnect after stream loss */
  reconnectIntervalMs?: number;
  /** Maximum reconnect attempts before entering error state */
  maxReconnectAttempts?: number;
}
