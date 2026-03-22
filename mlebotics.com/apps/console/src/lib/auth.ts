/**
 * Local mock auth — no external service required.
 *
 * Returns a hardcoded session that represents the dev user.
 * Replace with NextAuth.js / Clerk in production by swapping these exports.
 */

export type Role = 'OWNER' | 'ADMIN' | 'MEMBER' | 'VIEWER'

export interface MockUser {
  id: string
  email: string
  name: string
  avatarUrl: string | null
}

export interface MockOrganization {
  id: string
  name: string
  slug: string
  avatarUrl: string | null
}

export interface MockSession {
  userId: string
  organizationId: string
  role: Role
  user: MockUser
  organization: MockOrganization
}

// ── Mock data ─────────────────────────────────────────────────────────────────

const MOCK_USER: MockUser = {
  id: 'mock-user-1',
  email: 'eddie@mlebotics.com',
  name: 'Eddie Chongtham',
  avatarUrl: null,
}

const MOCK_ORG: MockOrganization = {
  id: 'mock-org-1',
  name: 'MLEbotics',
  slug: 'mlebotics',
  avatarUrl: null,
}

const MOCK_ORGS: Array<MockOrganization & { role: Role }> = [
  { ...MOCK_ORG, role: 'OWNER' },
]

// ── Auth functions ────────────────────────────────────────────────────────────

/** Returns the current session. Always non-null in local dev. */
export function getSession(): MockSession {
  return {
    userId: MOCK_USER.id,
    organizationId: MOCK_ORG.id,
    role: 'OWNER',
    user: MOCK_USER,
    organization: MOCK_ORG,
  }
}

/** Returns the session or throws — use in server components to guard routes. */
export function requireAuth(): MockSession {
  return getSession()
}

export function getMockUser(): MockUser {
  return MOCK_USER
}

export function getMockOrg(): MockOrganization {
  return MOCK_ORG
}

export function listOrgsForUser(): Array<MockOrganization & { role: Role }> {
  return MOCK_ORGS
}
