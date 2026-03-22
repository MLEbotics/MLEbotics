export default function WorldsPage() {
  const stats = [
    { label: 'Worlds', value: '0' },
    { label: 'Entities', value: '0' },
    { label: 'Active Streams', value: '0' },
    { label: 'Spatial Contexts', value: '0' },
  ]

  return (
    <div className="p-8 space-y-8">
      <div>
        <h1 className="text-xl font-bold text-white mb-1">Worlds</h1>
        <p className="text-gray-400 text-sm">
          Define spatial contexts, entities, and real-time data streams for your
          robotics environments.
        </p>
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

      {/* Canvas placeholder */}
      <div className="rounded-xl border border-dashed border-cyan-500/20 bg-cyan-500/5 p-16 text-center">
        <p className="text-sm font-medium text-cyan-400 mb-1">World Canvas</p>
        <p className="text-xs text-gray-500">
          Phase 3 — drag-and-drop world editor will be built here.
        </p>
        <button className="mt-6 rounded-lg bg-cyan-500/10 border border-cyan-500/20 px-4 py-2 text-xs text-cyan-400 hover:bg-cyan-500/20 transition-colors">
          + New World
        </button>
      </div>
    </div>
  )
}
