import type { Metadata } from 'next'
import Link from 'next/link'
import './globals.css'
import { ChatWidget } from '@/components/ChatWidget'

export const metadata: Metadata = {
  title: 'MLEbotics Docs',
  description: 'Platform documentation for the MLEbotics robotics and AI OS',
}

const navItems = [
  { section: null,           href: '/',                   label: 'Overview' },
  { section: 'Core',        href: '/event-bus',           label: 'Event Bus' },
  { section: null,           href: '/world-engine',        label: 'World Engine' },
  { section: null,           href: '/automation-engine',   label: 'Automation Engine' },
  { section: null,           href: '/plugin-engine',       label: 'Plugin Engine' },
  { section: 'Platform',    href: '/autonomy-engine',     label: 'Autonomy Engine' },
  { section: null,           href: '/marketplace',         label: 'Marketplace' },
  { section: 'Enterprise',  href: '/enterprise',          label: 'Enterprise' },
]

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-gray-950 text-gray-100 antialiased">
        <div className="flex min-h-screen">
          {/* Docs sidebar */}
          <aside className="w-64 flex-shrink-0 border-r border-gray-800 bg-gray-950 px-4 py-8">
            <div className="mb-8">
              <a href="https://mlebotics.com" className="logo-glow tracking-tight text-sm">MLEbotics</a>
              <span className="ml-2 rounded border border-indigo-500/30 px-1.5 py-0.5 text-[10px] font-semibold text-indigo-400">
                DOCS
              </span>
            </div>
            <nav className="space-y-1">
              {navItems.map(({ section, href, label }) => (
                <div key={href}>
                  {section && (
                    <p className="mt-4 mb-1 px-3 text-[10px] font-semibold uppercase tracking-widest text-gray-500">
                      {section}
                    </p>
                  )}
                  <Link
                    href={href}
                    className="block rounded-md px-3 py-2 text-sm text-gray-400 transition-colors hover:bg-gray-800 hover:text-white"
                  >
                    {label}
                  </Link>
                </div>
              ))}
            </nav>
          </aside>

          {/* Content area */}
          <main className="flex-1 overflow-auto px-8 py-8 lg:px-16">
            <div className="mx-auto max-w-3xl">{children}</div>
          </main>
        </div>
        <ChatWidget />
      </body>
    </html>
  )
}
