# Plugin Marketplace

**Phase 5 — Plugin Distribution System (Planned)**

The MLEbotics Marketplace is the distribution layer for plugins built on top of the platform. Developers publish `PluginManifest`-compatible packages; operators install them into their organization with one click.

---

## What Is a Plugin?

A plugin extends the platform with new capabilities — a custom sensor driver, a new automation step type, a UI panel, or a third-party integration. Plugins are declared using the `PluginManifest` schema (`platform/plugins/types.ts`).

---

## Plugin Lifecycle

```
Developer
  → Packages plugin (PluginManifest + source)
  → Publishes to Marketplace registry
  → Marketplace validates and signs package

Operator
  → Browses Marketplace in apps/console
  → Installs plugin into organization
  → Platform loads plugin, grants declared permissions
  → Plugin appears in available capabilities
```

---

## Marketplace Structure

| Area | Description |
|---|---|
| **Registry** | Stores published plugin packages and versions |
| **Discovery** | Search/filter by capability, category, rating |
| **Install API** | Installs plugin into an org, validates permissions |
| **Permissions Sandbox** | Each plugin runs with only its declared `PluginPermission[]` |
| **Ratings & Reviews** | Community feedback system |

---

## Revenue Model (Planned)

- **Free** — open-source plugins, no cost
- **Paid** — one-time purchase or subscription, developer keeps 80%
- **Enterprise** — private plugins, internal-only registry

---

## Integration Points

| Platform | Role |
|---|---|
| `platform/plugins/types.ts` | Core plugin schema — `PluginManifest`, `PluginPermission`, `Plugin` |
| `packages/api` | `pluginRouter` — install, uninstall, list, getManifest |
| `apps/console /plugins` | Marketplace browse + install UI |
| `infra/db` — `Plugin` model | Stores installed plugins per organization |

---

## Phase 5 TODOs

<!-- TODO: design plugin registry storage (S3 or Firestore) -->
<!-- TODO: implement pluginRouter in packages/api for install/uninstall/list -->
<!-- TODO: build marketplace browse page in apps/console/app/(dashboard)/plugins -->
<!-- TODO: implement permission sandbox (isolate plugin execution context) -->
<!-- TODO: add Plugin model to infra/db/prisma/schema.prisma -->
<!-- TODO: implement plugin signing and verification pipeline -->
<!-- TODO: write developer documentation for publishing a plugin -->
