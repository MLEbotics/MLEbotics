// platform/world-engine/index.ts
// WorldEngine — Phase 5 in-memory implementation.
// Maintains live entity and stream state for a single World.
// Persistence (Prisma) is Phase 6.

import type { IEventBus } from '../event-bus/types'
import type { World, Entity, Stream } from '../world/types'
import type { ID } from '../shared/types'

export class WorldEngine {
  private readonly _worldId: ID
  private readonly _bus: IEventBus

  // In-memory stores — keyed by entity / stream id
  private readonly _entities = new Map<ID, Entity>()
  private readonly _streams  = new Map<ID, Stream>()

  // Minimal world metadata
  private _world: Omit<World, 'entities' | 'streams'> | null = null

  constructor(worldId: ID, bus: IEventBus) {
    this._worldId = worldId
    this._bus     = bus
  }

  getWorldId(): ID { return this._worldId }

  // ── World ──────────────────────────────────────────────────────────────────

  /**
   * Initialise the engine with world metadata.
   * Must be called once before using entity / stream methods.
   */
  init(world: Omit<World, 'entities' | 'streams'>): void {
    this._world = world
  }

  getWorld(): World {
    if (!this._world) throw new Error('WorldEngine.init() has not been called')
    return {
      ...this._world,
      entities: Array.from(this._entities.values()),
      streams:  Array.from(this._streams.values()),
    }
  }

  // ── Entities ───────────────────────────────────────────────────────────────

  getEntity(entityId: ID): Entity {
    const entity = this._entities.get(entityId)
    if (!entity) throw new Error(`Entity not found: ${entityId}`)
    return entity
  }

  listEntities(): Entity[] {
    return Array.from(this._entities.values())
  }

  upsertEntity(data: Partial<Entity> & { id: ID }): Entity {
    const existing = this._entities.get(data.id)
    const now      = new Date()

    const entity: Entity = existing
      ? { ...existing, ...data, updatedAt: now }
      : {
          id:        data.id,
          worldId:   data.worldId ?? this._worldId,
          type:      data.type    ?? 'virtual',
          name:      data.name    ?? data.id,
          metadata:  data.metadata  ?? {},
          position:  data.position,
          createdAt: now,
          updatedAt: now,
        }

    this._entities.set(entity.id, entity)

    this._bus.emit({
      type:           existing ? 'world.entity.updated' : 'world.entity.created',
      organizationId: this._world?.orgId ?? '',
      source:         'world-engine',
      payload:        entity,
    })

    return entity
  }

  removeEntity(entityId: ID): void {
    const entity = this._entities.get(entityId)
    if (!entity) throw new Error(`Entity not found: ${entityId}`)

    this._entities.delete(entityId)

    // Also remove streams belonging to this entity
    for (const [sid, stream] of this._streams.entries()) {
      if (stream.entityId === entityId) this._streams.delete(sid)
    }

    this._bus.emit({
      type:           'world.entity.removed',
      organizationId: this._world?.orgId ?? '',
      source:         'world-engine',
      payload:        { entityId },
    })
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  listStreams(): Stream[] {
    return Array.from(this._streams.values())
  }

  startStream(stream: Stream): Stream {
    const active = { ...stream, active: true }
    this._streams.set(stream.id, active)

    this._bus.emit({
      type:           'world.stream.started',
      organizationId: this._world?.orgId ?? '',
      source:         'world-engine',
      payload:        active,
    })

    return active
  }

  stopStream(streamId: ID): void {
    const stream = this._streams.get(streamId)
    if (!stream) return

    const stopped = { ...stream, active: false }
    this._streams.set(streamId, stopped)

    this._bus.emit({
      type:           'world.stream.stopped',
      organizationId: this._world?.orgId ?? '',
      source:         'world-engine',
      payload:        stopped,
    })
  }
}

export type { World, Entity, Stream }
