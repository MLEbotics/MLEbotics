// platform/runtime.ts
// PlatformRuntime — Phase 5 top-level wiring.
// Creates a shared InMemoryEventBus and injects it into all engines.
// One PlatformRuntime per organization session.

import { InMemoryEventBus }  from './event-bus/runtime'
import { WorldEngine }       from './world-engine'
import { AutomationEngine }  from './automation-engine'
import { PluginEngine }      from './plugin-engine'

export class PlatformRuntime {
  readonly bus:        InMemoryEventBus
  readonly world:      WorldEngine
  readonly automation: AutomationEngine
  readonly plugin:     PluginEngine

  private constructor(
    orgId:   string,
    worldId: string,
    bus:     InMemoryEventBus,
  ) {
    this.bus        = bus
    this.world      = new WorldEngine(worldId, bus)
    this.automation = new AutomationEngine(bus)
    this.plugin     = new PluginEngine(orgId, bus)
  }

  /**
   * Factory — creates a fully wired runtime instance.
   * worldId defaults to `${orgId}-default` when not supplied.
   */
  static create(orgId: string, worldId?: string): PlatformRuntime {
    const bus = new InMemoryEventBus()
    return new PlatformRuntime(orgId, worldId ?? `${orgId}-default`, bus)
  }
}
