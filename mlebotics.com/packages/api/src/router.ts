import { z } from 'zod'
import { router, publicProcedure, protectedProcedure } from './trpc'
import { PlatformRuntime } from '@mlebotics/platform'
import type { Workflow } from '@mlebotics/platform'

// Mock data — matches seed.ts + createContext() mock session
const MOCK_USERS: Record<string, { id: string; email: string; name: string; avatarUrl: string | null }> = {
  'mock-user-1': { id: 'mock-user-1', email: 'eddie@mlebotics.com', name: 'Eddie Chongtham', avatarUrl: null },
}

const MOCK_ORGS: Record<string, { id: string; name: string; slug: string; avatarUrl: string | null }> = {
  'mock-org-1': { id: 'mock-org-1', name: 'MLEbotics', slug: 'mlebotics', avatarUrl: null },
}

const MOCK_MEMBERSHIPS: Array<{ userId: string; organizationId: string; role: 'OWNER' | 'ADMIN' | 'MEMBER' | 'VIEWER' }> = [
  { userId: 'mock-user-1', organizationId: 'mock-org-1', role: 'OWNER' },
]

// ── PlatformRuntime singletons (one per org — in-memory for Phase 5) ─────────

const _runtimes = new Map<string, PlatformRuntime>()

function getRuntimeForOrg(orgId: string): PlatformRuntime {
  if (!_runtimes.has(orgId)) {
    const rt = PlatformRuntime.create(orgId)
    _runtimes.set(orgId, rt)
    _seedDemoWorkflows(rt, orgId)
  }
  return _runtimes.get(orgId)!
}

function _seedDemoWorkflows(rt: PlatformRuntime, orgId: string): void {
  const now = new Date()

  const demoWorkflows: Workflow[] = [
    {
      id:          'wf-demo-1',
      name:        'Morning Status Report',
      description: 'Sends a daily platform status notification every morning.',
      orgId,
      status:      'active',
      trigger:     { type: 'schedule', config: { cron: '0 8 * * *' } },
      steps: [
        {
          id: 'step-1', workflowId: 'wf-demo-1', order: 1,
          type: 'notification', name: 'Send report',
          config: { message: 'Good morning — platform is running normally.' },
        },
      ],
      createdAt: now, updatedAt: now,
    },
    {
      id:          'wf-demo-2',
      name:        'Entity Health Check',
      description: 'Checks entity status and notifies on issues.',
      orgId,
      status:      'active',
      trigger:     { type: 'manual', config: {} },
      steps: [
        {
          id: 'step-1', workflowId: 'wf-demo-2', order: 1,
          type: 'delay', name: 'Brief pause',
          config: { ms: 100 },
        },
        {
          id: 'step-2', workflowId: 'wf-demo-2', order: 2,
          type: 'notification', name: 'Report health',
          config: { message: 'All entities reporting healthy.' },
        },
      ],
      createdAt: now, updatedAt: now,
    },
  ]

  for (const wf of demoWorkflows) rt.automation.registerWorkflow(wf)
}

// ── Mock plugin catalog ───────────────────────────────────────────────────────

const PLUGIN_CATALOG = [
  {
    id:           'mlebotics/ros2-adapter',
    name:         'ROS 2 Adapter',
    version:      '1.0.0',
    description:  'Connect ROS 2 robots to the MLEbotics platform.',
    author:       'MLEbotics',
    license:      'MIT',
    capabilities: ['robot_adapter', 'data_source'] as const,
    permissions:  ['read:robots', 'write:robots', 'read:streams'] as const,
    config:       [],
  },
  {
    id:           'mlebotics/slack-notifier',
    name:         'Slack Notifier',
    version:      '1.2.0',
    description:  'Send workflow notifications to a Slack channel.',
    author:       'MLEbotics',
    license:      'MIT',
    capabilities: ['notification'] as const,
    permissions:  ['network:outbound', 'read:org'] as const,
    config:       [
      { key: 'channel', type: 'string' as const, label: 'Channel', required: true },
      { key: 'token',   type: 'string' as const, label: 'Bot Token', required: true },
    ],
  },
  {
    id:           'mlebotics/dashboard-map',
    name:         'World Map Widget',
    version:      '0.9.0',
    description:  'Renders a live 2D/3D map of world entities on the dashboard.',
    author:       'MLEbotics',
    license:      'MIT',
    capabilities: ['dashboard_widget', 'world_entity'] as const,
    permissions:  ['read:org', 'read:streams'] as const,
    config:       [],
  },
]

// ── Health ────────────────────────────────────────────────────────────────────

const healthRouter = router({
  ping: publicProcedure.query(() => ({ status: 'ok' as const, timestamp: Date.now() })),
})

// ── User ──────────────────────────────────────────────────────────────────────

const userRouter = router({
  getCurrentUser: protectedProcedure.query(({ ctx }) => {
    const user = MOCK_USERS[ctx.session.userId]
    if (!user) throw new Error(`User not found: ${ctx.session.userId}`)
    return user
  }),
})

// ── Organization ──────────────────────────────────────────────────────────────

const organizationRouter = router({
  getCurrentOrganization: protectedProcedure
    .input(z.object({ slug: z.string() }).optional())
    .query(({ ctx, input }) => {
      const orgId = input?.slug
        ? Object.values(MOCK_ORGS).find((o) => o.slug === input.slug)?.id ?? ctx.session.organizationId
        : ctx.session.organizationId
      const org = MOCK_ORGS[orgId]
      if (!org) throw new Error(`Organization not found: ${orgId}`)
      return { ...org, role: ctx.session.role }
    }),

  listOrganizationsForUser: protectedProcedure.query(({ ctx }) => {
    return MOCK_MEMBERSHIPS
      .filter((m) => m.userId === ctx.session.userId)
      .map((m) => ({
        ...MOCK_ORGS[m.organizationId]!,
        role: m.role,
      }))
      .filter(Boolean)
  }),
})

// ── Workflow ──────────────────────────────────────────────────────────────────

const workflowRouter = router({
  list: protectedProcedure.query(({ ctx }) => {
    const rt = getRuntimeForOrg(ctx.session.organizationId)
    return rt.automation.listWorkflows()
  }),

  create: protectedProcedure
    .input(z.object({
      name:        z.string().min(1).max(120),
      description: z.string().max(500).optional(),
      triggerType: z.enum(['manual', 'schedule', 'event', 'webhook', 'condition']).default('manual'),
    }))
    .mutation(({ ctx, input }) => {
      const rt  = getRuntimeForOrg(ctx.session.organizationId)
      const now = new Date()

      const workflow: Workflow = {
        id:          crypto.randomUUID(),
        name:        input.name,
        description: input.description,
        orgId:       ctx.session.organizationId,
        status:      'draft',
        trigger:     { type: input.triggerType, config: {} },
        steps:       [],
        createdAt:   now,
        updatedAt:   now,
      }

      return rt.automation.registerWorkflow(workflow)
    }),

  trigger: protectedProcedure
    .input(z.object({ workflowId: z.string() }))
    .mutation(async ({ ctx, input }) => {
      const rt = getRuntimeForOrg(ctx.session.organizationId)
      return rt.automation.triggerWorkflow(input.workflowId, ctx.session.userId)
    }),

  getRun: protectedProcedure
    .input(z.object({ runId: z.string() }))
    .query(({ ctx, input }) => {
      const rt = getRuntimeForOrg(ctx.session.organizationId)
      return rt.automation.getRunStatus(input.runId)
    }),

  listRuns: protectedProcedure
    .input(z.object({ workflowId: z.string().optional() }))
    .query(({ ctx, input }) => {
      const rt = getRuntimeForOrg(ctx.session.organizationId)
      return rt.automation.listRuns(input.workflowId)
    }),

  cancel: protectedProcedure
    .input(z.object({ runId: z.string() }))
    .mutation(async ({ ctx, input }) => {
      const rt = getRuntimeForOrg(ctx.session.organizationId)
      await rt.automation.cancelRun(input.runId)
      return { cancelled: true }
    }),
})

// ── Marketplace ───────────────────────────────────────────────────────────────

const marketplaceRouter = router({
  listCatalog: publicProcedure.query(() => PLUGIN_CATALOG),

  install: protectedProcedure
    .input(z.object({ manifestId: z.string() }))
    .mutation(({ ctx, input }) => {
      const manifest = PLUGIN_CATALOG.find(p => p.id === input.manifestId)
      if (!manifest) throw new Error(`Plugin not found in catalog: ${input.manifestId}`)

      const rt = getRuntimeForOrg(ctx.session.organizationId)
      return rt.plugin.install(manifest as unknown as Parameters<typeof rt.plugin.install>[0])
    }),

  listInstalled: protectedProcedure.query(({ ctx }) => {
    const rt = getRuntimeForOrg(ctx.session.organizationId)
    return rt.plugin.listPlugins()
  }),

  activate: protectedProcedure
    .input(z.object({ pluginId: z.string() }))
    .mutation(({ ctx, input }) => {
      const rt = getRuntimeForOrg(ctx.session.organizationId)
      rt.plugin.activate(input.pluginId)
      return { activated: true }
    }),

  uninstall: protectedProcedure
    .input(z.object({ pluginId: z.string() }))
    .mutation(({ ctx, input }) => {
      const rt = getRuntimeForOrg(ctx.session.organizationId)
      rt.plugin.uninstall(input.pluginId)
      return { uninstalled: true }
    }),
})

// ── App router ────────────────────────────────────────────────────────────────

export const appRouter = router({
  health:       healthRouter,
  user:         userRouter,
  organization: organizationRouter,
  workflow:     workflowRouter,
  marketplace:  marketplaceRouter,
})

export type AppRouter = typeof appRouter
