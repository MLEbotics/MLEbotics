const statusColors: Record<string, string> = {
  online:  'bg-emerald-500',
  offline: 'bg-gray-600',
  error:   'bg-red-500',
}

export default function RobotsPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Robots</h1>
          <p className="mt-1 text-sm text-gray-400">Connected robots and their current status.</p>
        </div>
        <button className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500">
          + Add Robot
        </button>
      </div>

      {/* Status legend */}
      <div className="flex items-center gap-4">
        {Object.entries(statusColors).map(([status, color]) => (
          <div key={status} className="flex items-center gap-1.5 text-xs text-gray-400">
            <span className={`h-2 w-2 rounded-full ${color}`} />
            <span className="capitalize">{status}</span>
          </div>
        ))}
      </div>

      {/* Empty state */}
      <div className="flex flex-col items-center justify-center rounded-lg border border-dashed border-gray-700 bg-gray-900 py-24 text-center">
        <div className="mb-4 h-12 w-12 rounded-full bg-gray-800" />
        <h3 className="text-sm font-semibold text-white">No robots connected</h3>
        <p className="mt-1 text-sm text-gray-500">Add a robot to start monitoring and controlling it.</p>
        <button className="mt-4 rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500">
          + Add Robot
        </button>
      </div>
    </div>
  )
}
