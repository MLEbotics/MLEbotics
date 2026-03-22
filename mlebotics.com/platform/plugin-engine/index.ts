// platform/plugin-engine/index.ts
// PluginEngine — Phase 5 in-memory implementation.
// Full lifecycle: install → activate ↔ deactivate → uninstall.
// No sandbox; real isolation and config schema validation are Phase 6.

import type { IEventBus } from '../event-bus/types'
import type { Plugin, PluginManifest, PluginStatus, PluginPermission } from '../plugins/types'
import type { ID } from '../shared/types'

// Permissions that are safe to grant in Phase 5 (all declared permissions)
const ALLOWED_PERMISSIONS: ReadonlySet<PluginPermission> = new Set<PluginPermission>([
  'read:org',
  'write:workflows',
  'read:robots',
  'write:robots',
  'read:streams',
  'write:streams',
  'network:outbound',
])

export class PluginEngine {
  private readonly _orgId:    string
  private readonly _bus:      IEventBus
  private readonly _registry = new Map<ID, Plugin>()

  constructor(orgId: string, bus: IEventBus) {
    this._orgId = orgId
    this._bus   = bus
  }

  // ── Installation ───────────────────────────────────────────────────────────

  install(manifest: PluginManifest): Plugin {
    // Validate that all declared permissions are in the allowed set
    const unknown = manifest.permissions.filter(p => !ALLOWED_PERMISSIONS.has(p))
    if (unknown.length > 0) {
      throw new Error(`PluginEngine: unknown permissions declared: ${unknown.join(', ')}`)
    }

    // Check for duplicate install
    const existing = this._findByManifestId(manifest.id)
    if (existing) {
      throw new Error(`Plugin already installed: ${manifest.id}`)
    }

    const now: Date = new Date()
    const plugin: Plugin = {
      id:          crypto.randomUUID(),
      orgId:       this._orgId,
      manifestId:  manifest.id,
      manifest,
      status:      'pending_config',
      config:      {},
      installedAt: now,
      updatedAt:   now,
    }

    this._registry.set(plugin.id, plugin)

    this._bus.emit({
      type:           'plugin.installed',
      organizationId: this._orgId,
      source:         'plugin-engine',
      payload:        { pluginId: plugin.id, manifestId: manifest.id },
    })

    return plugin
  }

  activate(pluginId: ID): void {
    const plugin = this._getPlugin(pluginId)
    if (plugin.status === 'active') return

    const updated = { ...plugin, status: 'active' as PluginStatus, updatedAt: new Date() }
    this._registry.set(pluginId, updated)
  }

  deactivate(pluginId: ID): void {
    const plugin = this._getPlugin(pluginId)
    if (plugin.status === 'disabled') return

    const updated = { ...plugin, status: 'disabled' as PluginStatus, updatedAt: new Date() }
    this._registry.set(pluginId, updated)
  }

  uninstall(pluginId: ID): void {
    const plugin = this._getPlugin(pluginId)

    // Ensure it is deactivated first
    if (plugin.status === 'active') {
      this.deactivate(pluginId)
    }

    this._registry.delete(pluginId)

    this._bus.emit({
      type:           'plugin.uninstalled',
      organizationId: this._orgId,
      source:         'plugin-engine',
      payload:        { pluginId, manifestId: plugin.manifestId },
    })
  }

  // ── Queries ─────────────────────────────────────────────────────────────────

  listPlugins(): Plugin[] {
    return Array.from(this._registry.values())
  }

  getPlugin(pluginId: ID): Plugin {
    return this._getPlugin(pluginId)
  }

  getStatus(pluginId: ID): PluginStatus {
    return this._getPlugin(pluginId).status
  }

  updateConfig(pluginId: ID, config: Record<string, unknown>): Plugin {
    const plugin  = this._getPlugin(pluginId)
    const updated = { ...plugin, config: { ...plugin.config, ...config }, updatedAt: new Date() }
    this._registry.set(pluginId, updated)
    return updated
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  private _getPlugin(pluginId: ID): Plugin {
    const plugin = this._registry.get(pluginId)
    if (!plugin) throw new Error(`Plugin not found: ${pluginId}`)
    return plugin
  }

  private _findByManifestId(manifestId: string): Plugin | undefined {
    for (const plugin of this._registry.values()) {
      if (plugin.manifestId === manifestId) return plugin
    }
    return undefined
  }
}

export type { Plugin, PluginManifest, PluginStatus }
