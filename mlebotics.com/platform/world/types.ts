// platform/world/types.ts
// Phase 3 — World Engine TypeScript interfaces
// These define the shape of world objects. No runtime logic here.

/** A World is the top-level spatial and logical container for all entities. */
export interface World {
  id:          string
  name:        string
  slug:        string
  description?: string
  orgId:       string
  createdAt:   Date
  updatedAt:   Date
  entities:    Entity[]
  streams:     Stream[]
}

/**
 * An Entity is any object that exists inside a World.
 * Entities can be physical (robots, sensors) or virtual (agents, zones).
 */
export interface Entity {
  id:         string
  worldId:    string
  type:       EntityType
  name:       string
  metadata:   Record<string, unknown>
  position?:  Vector3
  createdAt:  Date
  updatedAt:  Date
}

export type EntityType =
  | 'robot'
  | 'sensor'
  | 'actuator'
  | 'zone'
  | 'agent'
  | 'virtual'

/** A 3D position vector for spatial entity placement. */
export interface Vector3 {
  x: number
  y: number
  z: number
}

/**
 * A Stream is a live data channel associated with an entity.
 * Examples: telemetry feed, camera stream, sensor readings.
 */
export interface Stream {
  id:       string
  entityId: string
  worldId:  string
  name:     string
  type:     StreamType
  schema:   Record<string, unknown>
  active:   boolean
}

export type StreamType =
  | 'telemetry'
  | 'video'
  | 'audio'
  | 'sensor'
  | 'event'
  | 'custom'
