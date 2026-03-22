# Enterprise Features

**Phase 5 — Enterprise Tier (Planned)**

The Enterprise tier unlocks features for large organizations that need advanced access control, compliance, audit trails, and dedicated infrastructure.

---

## Feature Overview

| Feature | Description |
|---|---|
| **SSO / SAML 2.0** | Single Sign-On via organizational identity provider (Okta, Azure AD, etc.) |
| **SCIM Provisioning** | Automatic user provisioning and deprovisioning |
| **Advanced RBAC** | Custom roles beyond Owner/Admin/Member/Viewer |
| **Audit Logs** | Immutable log of every action, modelled as `AuditEvent` (see `platform/shared/types.ts`) |
| **Data Residency** | Choose cloud region for data storage compliance |
| **SLA** | 99.99% uptime SLA with dedicated support |
| **Billing** | Seat-based or usage-based billing via Stripe integration |
| **Private Marketplace** | Internal-only plugin registry |

---

## Access Control Model

The platform ships with four built-in roles:

```
OWNER   — full org control, billing, member management
ADMIN   — all OWNER rights except billing/delete org
MEMBER  — create and edit resources within org
VIEWER  — read-only access to all resources
```

Enterprise tier adds:

- **Custom roles** with granular permission sets
- **Resource-level permissions** (e.g., VIEWER for robots but ADMIN for workflows)
- **Cross-org sharing** for multi-tenant enterprise deployments

---

## Compliance & Certifications (Planned)

| Standard | Status |
|---|---|
| SOC 2 Type II | Planned — Phase 5 |
| GDPR | Cookie policy + data deletion API — Phase 5 |
| ISO 27001 | Long-term roadmap |
| HIPAA | Not in scope |

---

## Billing

<!-- TODO: integrate Stripe for seat-based billing (Stripe customer per Organization) -->
<!-- TODO: add billing portal route in apps/console -->
<!-- TODO: add Subscription and Invoice models to infra/db/prisma/schema.prisma -->

---

## Integration Points

| Platform | Role |
|---|---|
| `infra/db` — `Organization`, `Role` | Core identity and RBAC |
| `packages/api` — `protectedProcedure` | RBAC middleware stub (Phase 2) |
| `platform/shared/types.ts` — `AuditEvent` | Audit log schema |
| `apps/console` — settings route | Billing, SSO, member management UI |

---

## Phase 5 TODOs

<!-- TODO: implement Clerk SSO + SAML 2.0 integration in packages/auth -->
<!-- TODO: implement SCIM endpoint in packages/api -->
<!-- TODO: implement AuditEvent persistence in infra/db -->
<!-- TODO: expose audit log query API in packages/api --> 
<!-- TODO: add billing portal and plan management in apps/console/settings -->
<!-- TODO: write SOC 2 control mapping document -->
<!-- TODO: implement GDPR data export and deletion endpoints -->
