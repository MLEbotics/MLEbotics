import Link from 'next/link'

const docs = [
  {
    href: '/autonomy-engine',
    title: 'Autonomy Engine',
    phase: 5,
    description:
      'AI decision loop architecture — Planner, Executor, Safety Controller. Integration points with the World Engine and Automation Engine.',
  },
  {
    href: '/marketplace',
    title: 'Plugin Marketplace',
    phase: 5,
    description:
      'Plugin lifecycle, publish/install flow, permission sandbox, and revenue model for the MLEbotics marketplace.',
  },
  {
    href: '/enterprise',
    title: 'Enterprise Features',
    phase: 5,
    description:
      'SSO, SCIM provisioning, advanced RBAC, audit logs, data residency, billing, and compliance (SOC 2, GDPR).',
  },
]

export default function DocsIndex() {
  return (
    <div className="space-y-10">
      <div>
        <h1 className="text-3xl font-bold text-white">MLEbotics Platform Docs</h1>
        <p className="mt-3 text-gray-400">
          Technical documentation for the MLEbotics Robotics + AI Automation OS.
          This covers Phase 5 planned features — autonomy, marketplace, and enterprise.
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-1 lg:grid-cols-1">
        {docs.map(({ href, title, phase, description }) => (
          <Link
            key={href}
            href={href}
            className="group block rounded-lg border border-gray-800 bg-gray-900 p-6 transition-colors hover:border-indigo-500/50 hover:bg-gray-800"
          >
            <div className="flex items-center gap-3">
              <h2 className="text-lg font-semibold text-white group-hover:text-indigo-400">
                {title}
              </h2>
              <span className="rounded border border-indigo-500/30 px-1.5 py-0.5 text-[10px] font-semibold text-indigo-400">
                Phase {phase}
              </span>
            </div>
            <p className="mt-2 text-sm text-gray-400">{description}</p>
          </Link>
        ))}
      </div>

      <div className="rounded-lg border border-amber-500/20 bg-amber-500/5 p-4">
        <p className="text-sm text-amber-400">
          ⚠️ Phase 5 is planned. Items marked with{' '}
          <code className="rounded bg-gray-800 px-1 py-0.5 text-xs text-gray-300">
            {'// TODO'}
          </code>{' '}
          in the codebase are integration points for future implementation.
        </p>
      </div>
    </div>
  )
}
