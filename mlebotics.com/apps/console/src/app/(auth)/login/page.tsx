'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import {
  signInWithGoogle,
  signInWithMicrosoft,
  signInWithApple,
  signInWithEmail,
  registerWithEmail,
  isAuthorized,
} from '@/lib/firebase'

type Mode = 'sign-in' | 'register'

export default function LoginPage() {
  const router = useRouter()
  const [mode, setMode] = useState<Mode>('sign-in')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function handleOAuth(fn: () => Promise<{ user: import('firebase/auth').User }>) {
    setError('')
    setLoading(true)
    try {
      const { user } = await fn()
      if (!isAuthorized(user)) return
      router.replace('/dashboard')
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e)
      if (!msg.includes('popup-closed')) setError(msg)
    } finally {
      setLoading(false)
    }
  }

  async function handleEmailSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const fn = mode === 'sign-in' ? signInWithEmail : registerWithEmail
      const { user } = await fn(email, password)
      if (!isAuthorized(user)) return
      router.replace('/dashboard')
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-gray-950 px-4">
      <div className="w-full max-w-sm">

        {/* Logo */}
        <div className="mb-8 text-center">
          <span className="logo-glow text-xl tracking-tight">MLEbotics</span>
          <p className="mt-2 text-sm text-gray-500">Console — sign in to continue</p>
        </div>

        <div className="rounded-xl border border-gray-800 bg-gray-900 p-8 shadow-xl">
          <h1 className="mb-6 text-lg font-bold text-white">
            {mode === 'sign-in' ? 'Sign in' : 'Create account'}
          </h1>

          {/* OAuth buttons */}
          <div className="flex flex-col gap-3 mb-6">
            <button
              onClick={() => handleOAuth(signInWithGoogle)}
              disabled={loading}
              className="flex items-center justify-center gap-3 rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm font-medium text-gray-200 hover:bg-gray-700 hover:border-gray-600 transition-colors disabled:opacity-50"
            >
              <GoogleIcon />
              Continue with Google
            </button>
            <button
              onClick={() => handleOAuth(signInWithMicrosoft)}
              disabled={loading}
              className="flex items-center justify-center gap-3 rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm font-medium text-gray-200 hover:bg-gray-700 hover:border-gray-600 transition-colors disabled:opacity-50"
            >
              <MicrosoftIcon />
              Continue with Microsoft
            </button>
            <button
              onClick={() => handleOAuth(signInWithApple)}
              disabled={loading}
              className="flex items-center justify-center gap-3 rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm font-medium text-gray-200 hover:bg-gray-700 hover:border-gray-600 transition-colors disabled:opacity-50"
            >
              <AppleIcon />
              Continue with Apple
            </button>
          </div>

          <div className="relative mb-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-gray-700" />
            </div>
            <div className="relative flex justify-center text-xs text-gray-500">
              <span className="bg-gray-900 px-2">or use email</span>
            </div>
          </div>

          {/* Email/password form */}
          <form onSubmit={handleEmailSubmit} className="flex flex-col gap-3">
            <input
              type="email"
              placeholder="Email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              required
              className="rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-cyan-500 focus:outline-none"
            />
            <input
              type="password"
              placeholder="Password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              required
              minLength={6}
              className="rounded-lg border border-gray-700 bg-gray-800 px-4 py-2.5 text-sm text-white placeholder-gray-500 focus:border-cyan-500 focus:outline-none"
            />
            {error && (
              <p className="rounded-lg bg-red-500/10 border border-red-500/20 px-3 py-2 text-xs text-red-400">{error}</p>
            )}
            <button
              type="submit"
              disabled={loading}
              className="mt-1 rounded-lg bg-cyan-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-cyan-500 transition-colors disabled:opacity-50"
            >
              {loading ? 'Please wait…' : mode === 'sign-in' ? 'Sign in' : 'Create account'}
            </button>
          </form>

          {/* Toggle mode */}
          <p className="mt-5 text-center text-xs text-gray-500">
            {mode === 'sign-in' ? "Don't have an account? " : 'Already have an account? '}
            <button
              onClick={() => { setMode(mode === 'sign-in' ? 'register' : 'sign-in'); setError('') }}
              className="text-cyan-400 hover:underline"
            >
              {mode === 'sign-in' ? 'Create one' : 'Sign in'}
            </button>
          </p>
        </div>

        <p className="mt-6 text-center text-xs text-gray-600">
          Access is open during this testing window.
        </p>
      </div>
    </main>
  )
}

function GoogleIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
    </svg>
  )
}

function MicrosoftIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 21 21" fill="none">
      <rect x="1" y="1" width="9" height="9" fill="#F25022"/>
      <rect x="11" y="1" width="9" height="9" fill="#7FBA00"/>
      <rect x="1" y="11" width="9" height="9" fill="#00A4EF"/>
      <rect x="11" y="11" width="9" height="9" fill="#FFB900"/>
    </svg>
  )
}

function AppleIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 814 1000" fill="currentColor" className="text-white">
      <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76 0-103 40.8-165 40.8s-105.3-60.7-155.5-127.4c-58-73.9-105.2-187.2-105.2-294.9 0-141.4 92.4-216.3 183-216.3 48.1 0 88.1 31.8 118.1 31.8 28.7 0 73.8-33.8 131.6-33.8 21.2 0 102.1 1.9 158.2 76.1zm-234.7-172c22.8-27.9 39.2-66.8 39.2-105.7 0-5.1-.4-10.3-1.3-14.5-37 1.3-81.6 24.7-108.9 56-20.9 23.8-40.4 62.7-40.4 101.9 0 5.7.9 11.4 1.3 13.3 2.6.4 6.7.6 10.8.6 33.1 0 75.4-22.2 99.3-51.6z"/>
    </svg>
  )
}

