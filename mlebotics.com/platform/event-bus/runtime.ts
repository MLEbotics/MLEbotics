// platform/event-bus/runtime.ts
// InMemoryEventBus — Phase 5 runtime implementation of IEventBus.
// Uses a Map of event type → handler list. Thread-safe for single-process Node.

import type { EventType, PlatformEvent, EventHandler, EventSubscription, IEventBus } from './types'
import type { ID } from '../shared/types'

type AnyHandler = EventHandler<unknown>

export class InMemoryEventBus implements IEventBus {
  // subscriptionId → { types, handler }
  private readonly _subs = new Map<ID, { types: EventType[]; handler: AnyHandler }>()

  subscribe<TPayload = unknown>(
    types: EventType[],
    handler: EventHandler<TPayload>,
  ): EventSubscription {
    const id = crypto.randomUUID()
    this._subs.set(id, { types, handler: handler as AnyHandler })
    return { id, types }
  }

  unsubscribe(subscriptionId: ID): void {
    this._subs.delete(subscriptionId)
  }

  emit<TPayload = unknown>(
    partial: Omit<PlatformEvent<TPayload>, 'id' | 'timestamp'>,
  ): void {
    const event: PlatformEvent<TPayload> = {
      ...partial,
      id: crypto.randomUUID(),
      timestamp: new Date(),
    }

    for (const { types, handler } of this._subs.values()) {
      if (types.includes(event.type)) {
        // Fire-and-forget async handlers — errors are swallowed in Phase 5
        // (Phase 6 will add dead-letter queue + retry logic)
        try {
          const result = handler(event as PlatformEvent<unknown>)
          if (result instanceof Promise) {
            result.catch((err: unknown) => {
              console.error(`[EventBus] Handler error (${event.type}):`, err)
            })
          }
        } catch (err) {
          console.error(`[EventBus] Sync handler error (${event.type}):`, err)
        }
      }
    }
  }

  /** Returns the number of active subscriptions — useful for testing. */
  get subscriptionCount(): number {
    return this._subs.size
  }
}
