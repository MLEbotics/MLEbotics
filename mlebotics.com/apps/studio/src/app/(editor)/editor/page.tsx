const QUICK_LINKS = [
  { href: '/worlds',    icon: '🌐', label: 'Worlds',    desc: 'Spatial contexts & entities' },
  { href: '/workflows', icon: '⚡', label: 'Workflows', desc: 'Event-driven automation' },
  { href: '/plugins',   icon: '🧩', label: 'Plugins',   desc: 'Marketplace & integrations' },
]

export default function EditorPage() {
  return (
    <div className="flex flex-col items-center justify-center h-full text-center gap-8 p-12">
      <div>
        <div className="w-16 h-16 mx-auto rounded-2xl bg-cyan-400/10 border border-cyan-400/20 flex items-center justify-center mb-4">
          <span className="text-2xl">🎨</span>
        </div>
        <h1 className="text-2xl font-bold text-white mb-2">MLEbotics Studio</h1>
        <p className="text-gray-400 max-w-md leading-relaxed text-sm">
          Visual editor for building worlds, designing workflows, and managing
          plugins. Select a workspace from the sidebar to begin.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 w-full max-w-xl">
        {QUICK_LINKS.map((l) => (
          <a
            key={l.href}
            href={l.href}
            className="rounded-xl border border-gray-800 bg-gray-900 p-5 text-left hover:border-cyan-500/40 hover:bg-gray-800/60 transition-colors group"
          >
            <span className="text-2xl">{l.icon}</span>
            <p className="mt-3 text-sm font-semibold text-white group-hover:text-cyan-400 transition-colors">{l.label}</p>
            <p className="text-xs text-gray-500 mt-1">{l.desc}</p>
          </a>
        ))}
      </div>

      <p className="text-xs text-gray-700 border border-gray-800 rounded-lg px-4 py-2">
        Phase 3 — full canvas editor will be built here
      </p>
    </div>
  )
}
