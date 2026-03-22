'use client'

import { ChevronDown, Building2, Check } from 'lucide-react'
import { useState } from 'react'
import { trpc } from '@/lib/trpc'

export function OrgSwitcher() {
  const [open, setOpen] = useState(false)
  const { data: orgs = [] } = trpc.organization.listOrganizationsForUser.useQuery()
  const [currentId, setCurrentId] = useState<string | null>(null)
  const current = orgs.find((o) => o.id === currentId) ?? orgs[0]

  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center gap-2 px-3 py-2 rounded-lg bg-gray-800/60 hover:bg-gray-800 transition-colors text-sm font-medium text-gray-200"
      >
        <Building2 size={15} className="text-cyan-400 flex-shrink-0" />
        <span className="truncate flex-1 text-left">{current?.name ?? '…'}</span>
        <ChevronDown size={13} className="text-gray-500 flex-shrink-0" />
      </button>

      {open && (
        <div className="absolute top-full mt-1 left-0 right-0 bg-gray-900 border border-gray-700 rounded-xl shadow-xl z-50 py-1">
          {orgs.map((org) => (
            <button
              key={org.id}
              onClick={() => { setCurrentId(org.id); setOpen(false) }}
              className="w-full flex items-center gap-2 px-3 py-2 hover:bg-gray-800 transition-colors text-sm text-gray-200"
            >
              <Building2 size={14} className="text-gray-500 flex-shrink-0" />
              <span className="flex-1 text-left">{org.name}</span>
              {current && org.id === current.id && (
                <Check size={13} className="text-cyan-400" />
              )}
            </button>
          ))}
          <div className="border-t border-gray-800 mt-1 pt-1">
            <button className="w-full flex items-center gap-2 px-3 py-2 hover:bg-gray-800 transition-colors text-xs text-gray-500">
              + New organization
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
