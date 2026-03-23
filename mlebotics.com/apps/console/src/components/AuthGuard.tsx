'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useAuth } from '@/lib/auth-context'

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const { user, authorized, loading } = useAuth()
  const router = useRouter()

  useEffect(() => {
    if (!loading && !user) router.replace('/login')
    if (!loading && user && !authorized) router.replace('/login?error=unauthorized')
  }, [user, authorized, loading, router])

  if (loading) {
    return (
      <div className="flex h-screen items-center justify-center bg-gray-950">
        <div className="text-sm text-gray-500 animate-pulse">Loading…</div>
      </div>
    )
  }

  if (!user || !authorized) return null

  return <>{children}</>
}
