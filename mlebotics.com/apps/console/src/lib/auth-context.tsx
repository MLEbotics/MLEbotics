'use client'

import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { watchAuthState, isAuthorized, type User } from './firebase'

interface AuthState {
  user: User | null
  authorized: boolean
  loading: boolean
}

const AuthContext = createContext<AuthState>({
  user: null,
  authorized: false,
  loading: true,
})

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ user: null, authorized: false, loading: true })

  useEffect(() => {
    const unsub = watchAuthState((user) => {
      setState({ user, authorized: isAuthorized(user), loading: false })
    })
    return unsub
  }, [])

  return <AuthContext.Provider value={state}>{children}</AuthContext.Provider>
}

export function useAuth() {
  return useContext(AuthContext)
}
