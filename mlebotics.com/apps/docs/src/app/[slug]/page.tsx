import { notFound } from 'next/navigation'
import { readFileSync } from 'fs'
import { join } from 'path'

// Valid slugs
const VALID_SLUGS = [
  'autonomy-engine',
  'marketplace',
  'enterprise',
  'event-bus',
  'world-engine',
  'automation-engine',
  'plugin-engine',
] as const

type Slug = (typeof VALID_SLUGS)[number]

const META: Record<Slug, { title: string; badge: string; badgeColor: string }> = {
  'autonomy-engine':   { title: 'Autonomy Engine',     badge: 'Phase 5', badgeColor: 'indigo' },
  'marketplace':       { title: 'Plugin Marketplace',  badge: 'Phase 5', badgeColor: 'indigo' },
  'enterprise':        { title: 'Enterprise Features', badge: 'Planned', badgeColor: 'gray'   },
  'event-bus':         { title: 'Event Bus',           badge: 'Phase 5', badgeColor: 'indigo' },
  'world-engine':      { title: 'World Engine',        badge: 'Phase 5', badgeColor: 'indigo' },
  'automation-engine': { title: 'Automation Engine',   badge: 'Phase 5', badgeColor: 'indigo' },
  'plugin-engine':     { title: 'Plugin Engine',       badge: 'Phase 5', badgeColor: 'indigo' },
}

export function generateStaticParams() {
  return VALID_SLUGS.map((slug) => ({ slug }))
}

// Simple markdown renderer (no external deps)
function renderMarkdown(raw: string): React.ReactNode[] {
  const lines = raw.split('\n')
  const nodes: React.ReactNode[] = []
  let i = 0

  while (i < lines.length) {
    const line = lines[i]!

    // Code fences
    if (line.startsWith('` ` `')) {
      // handled below — use actual backticks
    }
    if (line.startsWith('\u0060\u0060\u0060')) {
      const codeLang = line.slice(3).trim()
      const codeLines: string[] = []
      i++
      while (i < lines.length && !lines[i]!.startsWith('\u0060\u0060\u0060')) {
        codeLines.push(lines[i]!)
        i++
      }
      nodes.push(
        <div key={`code-${i}`} className="my-4 overflow-x-auto rounded-lg bg-gray-900 border border-gray-700">
          {codeLang && (
            <div className="border-b border-gray-700 px-4 py-1.5 text-[10px] font-semibold uppercase tracking-widest text-indigo-400">
              {codeLang}
            </div>
          )}
          <pre className="p-4 font-mono text-sm leading-relaxed text-gray-300">{codeLines.join('\n')}</pre>
        </div>
      )
      i++; continue
    }

    if (line.startsWith('### ')) {
      nodes.push(<h3 key={i} className="mt-6 mb-2 text-base font-semibold text-gray-100">{line.slice(4)}</h3>)
      i++; continue
    }
    if (line.startsWith('## ')) {
      nodes.push(<h2 key={i} className="mt-8 mb-3 text-xl font-bold text-white border-b border-gray-800 pb-2">{line.slice(3)}</h2>)
      i++; continue
    }
    if (line.startsWith('# ')) {
      i++; continue
    }

    // Bullet list
    if (line.startsWith('- ') || line.startsWith('* ')) {
      const items: React.ReactNode[] = []
      while (i < lines.length && (lines[i]!.startsWith('- ') || lines[i]!.startsWith('* '))) {
        items.push(<li key={i}>{lines[i]!.slice(2)}</li>)
        i++
      }
      nodes.push(<ul key={`ul-${i}`} className="my-3 list-disc space-y-1 pl-6 text-gray-300 text-sm">{items}</ul>)
      continue
    }

    if (line.trim() === '') { nodes.push(<div key={i} className="my-2" />); i++; continue }

    nodes.push(<p key={i} className="my-2 text-sm leading-relaxed text-gray-300">{line}</p>)
    i++
  }

  return nodes
}

// Next.js 15: params is a Promise
export default async function DocPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const typedSlug = slug as Slug

  if (!VALID_SLUGS.includes(typedSlug)) notFound()

  const meta = META[typedSlug]

  let raw: string
  try {
    raw = readFileSync(join(process.cwd(), `${typedSlug}.md`), 'utf-8')
  } catch {
    notFound()
  }

  const badgeClass = meta.badgeColor === 'indigo'
    ? 'border-indigo-500/30 text-indigo-400'
    : 'border-gray-600 text-gray-500'

  return (
    <div>
      <div className="mb-6">
        <h1 className="text-3xl font-bold text-white">{meta.title}</h1>
        <div className="mt-2">
          <span className={`rounded border px-1.5 py-0.5 text-[10px] font-semibold ${badgeClass}`}>
            {meta.badge}
          </span>
        </div>
      </div>
      <div>{renderMarkdown(raw)}</div>
    </div>
  )
}
