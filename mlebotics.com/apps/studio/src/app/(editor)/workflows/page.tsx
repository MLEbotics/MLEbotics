export default function WorkflowsPage() {
  const stats = [
    { label: 'Workflows', value: '0' },
    { label: 'Active Runs', value: '0' },
    { label: 'Triggers', value: '0' },
    { label: 'Avg Duration', value: '—' },
  ]

  return (
    <div className="p-8 space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold text-white mb-1">Workflows</h1>
          <p className="text-gray-400 text-sm">
            Design event-driven automation logic with a visual node editor.
          </p>
        </div>
        <button className="rounded-lg bg-indigo-600 hover:bg-indigo-500 transition-colors px-4 py-2 text-sm font-medium text-white">
          + New Workflow
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

      {/* Empty state */}
      <div className="rounded-xl border border-dashed border-gray-700 bg-gray-900/50 p-16 text-center">
        <div className="w-12 h-12 mx-auto mb-4 rounded-xl bg-indigo-600/10 border border-indigo-600/20 flex items-center justify-center">
          <span className="text-xl">⚡</span>
        </div>
        <p className="text-sm font-medium text-gray-300 mb-1">No workflows yet</p>
        <p className="text-xs text-gray-600 mb-6">
          Phase 3 — visual node editor will be built here.
        </p>
        <button className="rounded-lg bg-indigo-600/10 border border-indigo-600/20 px-4 py-2 text-xs text-indigo-400 hover:bg-indigo-600/20 transition-colors">
          + New Workflow
        </button>
      </div>
    </div>
  )
}
