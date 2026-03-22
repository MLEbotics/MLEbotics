// platform/plugins/types.ts
// Phase 3 — Plugin system TypeScript interfaces

/**
 * A PluginManifest describes a plugin's identity, capabilities, and requirements.
 * This is the contract every plugin must satisfy.
 */
export interface PluginManifest {
  id:           string         // unique slug, e.g. "mlebotics/ros2-adapter"
  name:         string
  version:      string         // semver
  description:  string
  author:       string
  license:      string
  homepage?:    string
  capabilities: PluginCapability[]
  permissions:  PluginPermission[]
  config:       PluginConfigSchema[]
}

export type PluginCapability =
  | 'workflow_step'      // adds new step types
  | 'robot_adapter'      // connects a new robot protocol
  | 'world_entity'       // adds new entity types to the World Engine
  | 'ui_panel'           // injects a custom sidebar / panel
  | 'dashboard_widget'   // adds a dashboard widget
  | 'data_source'        // provides a new stream source
  | 'notification'       // new notification channel

export type PluginPermission =
  | 'read:org'
  | 'write:workflows'
  | 'read:robots'
  | 'write:robots'
  | 'read:streams'
  | 'write:streams'
  | 'network:outbound'

export interface PluginConfigSchema {
  key:         string
  type:        'string' | 'number' | 'boolean' | 'select'
  label:       string
  description?: string
  required:    boolean
  default?:    unknown
  options?:    { label: string; value: string }[]  // for type: 'select'
}

/**
 * A Plugin is an installed + configured instance of a PluginManifest.
 */
export interface Plugin {
  id:          string
  orgId:       string
  manifestId:  string
  manifest:    PluginManifest
  status:      PluginStatus
  config:      Record<string, unknown>
  installedAt: Date
  updatedAt:   Date
}

export type PluginStatus = 'active' | 'disabled' | 'error' | 'pending_config'
