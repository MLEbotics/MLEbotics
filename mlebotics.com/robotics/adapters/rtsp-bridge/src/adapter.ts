import type { RTSPAdapterConfig, RTSPStreamState } from './types';

/**
 * RTSPBridgeAdapter — Phase 4 skeleton
 *
 * Ingests an RTSP video stream from a robot or IP camera and forwards
 * it to the MLEbotics platform video pipeline. Full implementation is Phase 4.
 */
export class RTSPBridgeAdapter {
  private config: RTSPAdapterConfig;
  private state: RTSPStreamState = 'idle';
  private reconnectAttempts = 0;

  constructor(config: RTSPAdapterConfig) {
    this.config = config;
  }

  getState(): RTSPStreamState {
    return this.state;
  }

  async connect(): Promise<void> {
    // TODO: spawn ffmpeg or node-rtsp-stream process to read this.config.rtspUrl
    // TODO: pipe decoded frames to platform video stream API
    // TODO: handle reconnect logic on stream drop
    throw new Error('RTSPBridgeAdapter.connect() not yet implemented');
  }

  async disconnect(): Promise<void> {
    // TODO: kill ffmpeg/stream process, clean up resources
    this.state = 'stopped';
    this.reconnectAttempts = 0;
  }
}
