const tabs = ['All', 'Active', 'Paused', 'Draft']

export default function WorkflowsPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Workflows</h1>
          <p className="mt-1 text-sm text-gray-400">Automate tasks across your robots and projects.</p>
        </div>
        <button className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500">
          + New Workflow
        </button>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 border-b border-gray-800">
        {tabs.map((tab, i) => (
          <button
            key={tab}
            className={`px-4 py-2 text-sm font-medium transition-colors ${
              i === 0
                ? 'border-b-2 border-indigo-500 text-white'
                : 'text-gray-500 hover:text-gray-300'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {/* Empty state */}
      <div className="flex flex-col items-center justify-center rounded-lg border border-dashed border-gray-700 bg-gray-900 py-24 text-center">
        <div className="mb-4 h-12 w-12 rounded-full bg-gray-800" />
        <h3 className="text-sm font-semibold text-white">No workflows yet</h3>
        <p className="mt-1 text-sm text-gray-500">Build your first automation workflow.</p>
        <button className="mt-4 rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500">
          + New Workflow
        </button>
      </div>
    </div>
  )
}
