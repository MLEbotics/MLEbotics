const PLUGIN_CATEGORIES = ['All', 'Robotics', 'Vision', 'Sensors', 'Automation', 'Data']

export default function PluginsPage() {
  const stats = [
    { label: 'Installed', value: '0' },
    { label: 'Available', value: '—' },
    { label: 'Updates', value: '0' },
    { label: 'Custom', value: '0' },
  ]

  return (
    <div className="p-8 space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-white mb-1">Plugins</h1>
          <p className="text-gray-400 text-sm">
            Browse, install, and configure platform plugins and integrations.
          </p>
        </div>
        <button className="rounded-lg bg-indigo-600 hover:bg-indigo-500 transition-colors px-4 py-2 text-sm font-medium text-white">
          + Upload Plugin
        </button>
      </div>

      {/* Stat row */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {stats.map((s) => (
          <div
            key={s.label}
            className="rounded-xl border border-gray-800 bg-gray-900 px-5 py-4"
          >
            <p className="text-2xl font-bold text-white">{s.value}</p>
            <p className="text-xs text-gray-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Category filter */}
      <div className="flex gap-2 flex-wrap">
        {PLUGIN_CATEGORIES.map((cat) => (
          <button
            key={cat}
            className="rounded-full border border-gray-700 bg-gray-900 px-3 py-1 text-xs text-gray-400 hover:border-indigo-600/50 hover:text-indigo-400 transition-colors first:border-indigo-600/50 first:text-indigo-400"
          >
            {cat}
          </button>
        ))}
      </div>

      {/* Empty state grid */}
      <div className="rounded-xl border border-dashed border-gray-700 bg-gray-900/50 p-16 text-center">
        <div className="w-12 h-12 mx-auto mb-4 rounded-xl bg-purple-600/10 border border-purple-600/20 flex items-center justify-center">
          <span className="text-xl">🧩</span>
        </div>
        <p className="text-sm font-medium text-gray-300 mb-1">No plugins installed</p>
        <p className="text-xs text-gray-600 mb-6">
          Phase 5 — plugin marketplace will be built here.
        </p>
        <button className="rounded-lg bg-purple-600/10 border border-purple-600/20 px-4 py-2 text-xs text-purple-400 hover:bg-purple-600/20 transition-colors">
          Browse Marketplace
        </button>
      </div>
    </div>
  )
}
