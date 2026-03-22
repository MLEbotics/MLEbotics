import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

/**
 * Local dev middleware — allows all routes.
 * In production: replace this with a real auth guard (NextAuth / Clerk).
 * The mock session in lib/auth.ts simulates an authenticated OWNER user.
 */
export function middleware(_request: NextRequest) {
  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
