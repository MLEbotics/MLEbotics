const stats = [
  { label: 'Active Projects', value: '0', change: '--', up: true },
  { label: 'Connected Robots', value: '0', change: '--', up: true },
  { label: 'Workflows Running', value: '0', change: '--', up: false },
  { label: 'Team Members', value: '1', change: '--', up: true },
]

const activity: { text: string; time: string }[] = []

export default function DashboardPage() {
  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-white">Dashboard</h1>
        <p className="mt-1 text-sm text-gray-400">Welcome back. Here&apos;s what&apos;s happening.</p>
      </div>

      {/* Stats grid */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {stats.map((s) => (
          <div key={s.label} className="rounded-lg border border-gray-800 bg-gray-900 p-5">
            <p className="text-xs font-medium uppercase tracking-wider text-gray-500">{s.label}</p>
            <p className="mt-2 text-3xl font-bold text-white">{s.value}</p>
            <p className={`mt-1 text-xs ${s.up ? 'text-emerald-400' : 'text-red-400'}`}>{s.change}</p>
          </div>
        ))}
      </div>

      {/* Two-col lower section */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Recent activity */}
        <div className="rounded-lg border border-gray-800 bg-gray-900 p-6">
          <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-gray-400">Recent Activity</h2>
          {activity.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <div className="mb-3 h-10 w-10 rounded-full bg-gray-800" />
              <p className="text-sm text-gray-500">No activity yet.</p>
              <p className="mt-1 text-xs text-gray-600">Actions will appear here once you start using the platform.</p>
            </div>
          ) : (
            <ul className="space-y-3">
              {activity.map((a, i) => (
                <li key={i} className="flex items-center justify-between text-sm">
                  <span className="text-gray-300">{a.text}</span>
                  <span className="text-gray-600">{a.time}</span>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Quick actions */}
        <div className="rounded-lg border border-gray-800 bg-gray-900 p-6">
          <h2 className="mb-4 text-sm font-semibold uppercase tracking-wider text-gray-400">Quick Actions</h2>
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: 'New Project',  href: '/projects' },
              { label: 'Add Robot',    href: '/robots' },
              { label: 'New Workflow', href: '/workflows' },
              { label: 'Settings',     href: '/settings' },
            ].map((action) => (
              <a
                key={action.href}
                href={action.href}
                className="flex items-center justify-center rounded-md border border-gray-700 bg-gray-800 px-4 py-3 text-sm font-medium text-gray-300 transition-colors hover:border-indigo-500 hover:bg-gray-700 hover:text-white"
              >
                {action.label}
              </a>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
