export default function AutomationPage() {
  return (
    <div className="p-8">
      <div className="flex items-center gap-3 mb-6">
        <h1 className="text-xl font-bold text-white">Automation Engine</h1>
        <span className="text-[10px] font-semibold text-amber-400 border border-amber-400/30 rounded px-1.5 py-0.5">PHASE 3</span>
      </div>
      <p className="text-gray-400 text-sm mb-6 max-w-xl leading-relaxed">
        The Automation Engine executes declarative workflows — sequences of steps triggered by
        events, schedules, or conditions. Steps can invoke robots, call APIs, or run AI agents.
      </p>
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
        {[
          { label: 'Workflows', count: 0, desc: 'Defined workflows' },
          { label: 'Active',    count: 0, desc: 'Currently running' },
          { label: 'Runs',      count: 0, desc: 'Total executions' },
        ].map(s => (
          <div key={s.label} className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <p className="text-2xl font-bold text-white">{s.count}</p>
            <p className="text-sm text-gray-200 font-medium">{s.label}</p>
            <p className="text-xs text-gray-500 mt-0.5">{s.desc}</p>
          </div>
        ))}
      </div>
      <div className="border border-dashed border-gray-800 rounded-xl p-10 text-center text-gray-600 text-sm">
        Workflow step editor — coming in Phase 3
      </div>
    </div>
  )
}
