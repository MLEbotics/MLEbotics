# robotics/adapters/rtsp-bridge

**Phase 4 — RTSP Video Bridge Adapter (Skeleton)**

Ingests video streams from RTSP-capable IP cameras and robots, transcodes them if needed, and pushes the stream to the MLEbotics platform video pipeline.

## Status

> ⚠️ **Skeleton only.** Full implementation is planned for Phase 4 of the MLEbotics roadmap.

## What This Adapter Does

| Direction | From → To | Description |
|---|---|---|
| Inbound | RTSP stream → Platform video stream | Live robot camera feed, IP camera footage |
| Outbound | Platform signal → RTSP adapter | Reconnect, quality change, stop stream |

## Config Schema

```json
{
  "rtsp_url": "rtsp://192.168.1.10:554/stream",
  "platform_robot_id": "<MLEbotics robot UUID>",
  "stream_name": "front-camera",
  "codec": "h264",
  "reconnect_interval_ms": 5000,
  "max_reconnect_attempts": 10
}
```

## Structure

```
src/
  types.ts      ← RTSPAdapterConfig, RTSPStreamState interfaces
  adapter.ts    ← RTSPBridgeAdapter class stub
  index.ts      ← Entry point
```

## Phase 4 TODOs

- [ ] Connect to RTSP source via `ffmpeg` or `node-rtsp-stream`
- [ ] Transcode to platform-compatible format (WebRTC / HLS / MJPEG)
- [ ] Push encoded frames to Platform video stream API
- [ ] Implement automatic reconnection with configurable backoff
- [ ] Support stream quality / bitrate selection
- [ ] Expose stream health telemetry (fps, dropped frames, latency)
