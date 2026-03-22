'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Globe, GitBranch, Puzzle, LayoutGrid } from 'lucide-react'

const nav = [
  { label: 'Editor',    href: '/editor',     icon: LayoutGrid },
  { label: 'Worlds',    href: '/worlds',     icon: Globe },
  { label: 'Workflows', href: '/workflows',  icon: GitBranch },
  { label: 'Plugins',   href: '/plugins',    icon: Puzzle },
]

export default function EditorLayout({ children }: { children: React.ReactNode }) {
  const path = usePathname()
  return (
    <div className="flex h-screen bg-gray-950 text-gray-100 overflow-hidden">
      {/* Sidebar */}
      <aside className="w-56 flex flex-col bg-gray-900 border-r border-gray-800">
        {/* Header */}
        <div className="flex h-16 items-center border-b border-gray-800 px-4 gap-3">
          <a href="https://mlebotics.com" className="logo-glow tracking-tight text-sm">MLEbotics</a>
          <span className="ml-auto text-[9px] font-semibold text-cyan-500 border border-cyan-500/30 rounded px-1.5 py-0.5 leading-none">
            STUDIO
          </span>
        </div>
        {/* Nav */}
        <nav className="flex flex-col gap-1 p-3">
          {nav.map(({ label, href, icon: Icon }) => (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors ${
                path === href ? 'bg-gray-800 text-cyan-400' : 'text-gray-400 hover:text-gray-100 hover:bg-gray-800'
              }`}
            >
              <Icon size={16} />
              <span>{label}</span>
            </Link>
          ))}
        </nav>
      </aside>

      {/* Main area */}
      <main className="flex-1 overflow-auto">{children}</main>
    </div>
  )
}
