# Plugin Engine

## Overview

The `PluginEngine` manages the full lifecycle of plugins installed within an organisation. It validates permissions at install time, tracks plugin state, and emits lifecycle events via the shared event bus.

## Plugin Lifecycle

```
install() → status: pending_config
activate() → status: active
deactivate() → status: disabled
uninstall() → removed from registry
```

## Plugin Capabilities

```
workflow_step | robot_adapter | world_entity
ui_panel | dashboard_widget | data_source | notification
```

## Plugin Permissions

```
read:org | write:workflows | read:robots | write:robots
read:streams | write:streams | network:outbound
```

All permissions listed above are allowed in Phase 5. The engine rejects any manifest declaring an unknown permission string.

## API

### Install a plugin

```typescript
const rt = PlatformRuntime.create('org-123')

const plugin = rt.plugin.install({
  id:           'mlebotics/slack-notifier',
  name:         'Slack Notifier',
  version:      '1.2.0',
  description:  'Send workflow notifications to Slack.',
  author:       'MLEbotics',
  license:      'MIT',
  capabilities: ['notification'],
  permissions:  ['network:outbound', 'read:org'],
  config:       [
    { key: 'channel', type: 'string', label: 'Channel', required: true },
    { key: 'token',   type: 'string', label: 'Bot Token', required: true },
  ],
})
// plugin.status === 'pending_config'
```

### Configure + activate

```typescript
const configured = rt.plugin.updateConfig(plugin.id, {
  channel: '#alerts',
  token:   'xoxb-...',
})

rt.plugin.activate(plugin.id)
// plugin.status === 'active'
```

### Deactivate and uninstall

```typescript
rt.plugin.deactivate(plugin.id)
rt.plugin.uninstall(plugin.id)
```

### List installed plugins

```typescript
const installed = rt.plugin.listPlugins()
// returns Plugin[] — all plugins in registry for this org
```

## Events Emitted

- `plugin.installed` — when a manifest is successfully installed
- `plugin.uninstalled` — when a plugin is removed

## Marketplace Catalog

The tRPC marketplace router exposes the plugin catalog (static in Phase 5):

- `marketplace.listCatalog` — public, no auth required
- `marketplace.install` — installs a catalog plugin for the session org
- `marketplace.listInstalled` — lists installed plugins
- `marketplace.activate` — activates a plugin
- `marketplace.uninstall` — removes a plugin

## Phase 6 Notes

- Persist plugin registry to Prisma
- Implement sandboxed execution (VM2, Deno workers, or WASM)
- Add `pending_config` → `active` transition gated on required config fields
- Add plugin signature verification before install
- Support plugin versioning and upgrades
