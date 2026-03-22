export default function ProjectsPage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Projects</h1>
          <p className="mt-1 text-sm text-gray-400">Manage and monitor your MLEbotics projects.</p>
        </div>
        <button className="rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500">
          + New Project
        </button>
      </div>

      {/* Empty state */}
      <div className="flex flex-col items-center justify-center rounded-lg border border-dashed border-gray-700 bg-gray-900 py-24 text-center">
        <div className="mb-4 h-12 w-12 rounded-full bg-gray-800" />
        <h3 className="text-sm font-semibold text-white">No projects yet</h3>
        <p className="mt-1 text-sm text-gray-500">Create your first project to get started.</p>
        <button className="mt-4 rounded-md bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500">
          + New Project
        </button>
      </div>
    </div>
  )
}
