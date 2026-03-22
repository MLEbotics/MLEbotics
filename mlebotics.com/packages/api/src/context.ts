// tRPC context — injected into every procedure
// Phase 2: mock session — wire to real auth (NextAuth / Clerk) in production.

export type Role = 'OWNER' | 'ADMIN' | 'MEMBER' | 'VIEWER'

export type Session = {
  userId: string
  organizationId: string
  role: Role
} | null

export type Context = {
  session: Session
  // db: PrismaClient  ← uncomment after: pnpm --filter @mlebotics/db db:generate
}

/**
 * Returns a non-null mock session in local dev.
 * In production: parse the auth token from the incoming request headers.
 */
export function createContext(): Context {
  return {
    session: {
      userId: 'mock-user-1',
      organizationId: 'mock-org-1',
      role: 'OWNER',
    },
  }
}
