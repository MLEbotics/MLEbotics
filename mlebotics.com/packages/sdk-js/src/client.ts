import type {
  PlatformClientOptions,
  HealthResponse,
  UserProfile,
  Organization,
} from './types';

/**
 * PlatformClient — Phase 5 skeleton
 *
 * JavaScript/TypeScript SDK for interacting with the MLEbotics platform API.
 * Intended for external integrations, robot firmware bridges, and partner apps.
 *
 * Full implementation is Phase 5.
 */
export class PlatformClient {
  private options: PlatformClientOptions;

  constructor(options: PlatformClientOptions) {
    if (!options.baseUrl) throw new Error('PlatformClient: baseUrl is required');
    this.options = options;
  }

  private authHeaders(): Record<string, string> {
    if (this.options.apiKey) return { 'x-api-key': this.options.apiKey };
    if (this.options.token) return { Authorization: `Bearer ${this.options.token}` };
    return {};
  }

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    const url = `${this.options.baseUrl}${path}`;
    const res = await fetch(url, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...this.authHeaders(),
        ...(init?.headers ?? {}),
      },
    });
    if (!res.ok) {
      throw new Error(`PlatformClient: ${res.status} ${res.statusText} — ${path}`);
    }
    return res.json() as Promise<T>;
  }

  // ─── Health ─────────────────────────────────────────────────────────────────

  async ping(): Promise<HealthResponse> {
    // TODO: wire to tRPC health.ping
    throw new Error('PlatformClient.ping() not yet implemented');
  }

  // ─── User ───────────────────────────────────────────────────────────────────

  async getCurrentUser(): Promise<UserProfile> {
    // TODO: wire to tRPC user.getCurrentUser
    throw new Error('PlatformClient.getCurrentUser() not yet implemented');
  }

  // ─── Organizations ──────────────────────────────────────────────────────────

  async listOrganizations(): Promise<Organization[]> {
    // TODO: wire to tRPC organization.listOrganizationsForUser
    throw new Error('PlatformClient.listOrganizations() not yet implemented');
  }

  async getOrganization(slug: string): Promise<Organization> {
    // TODO: wire to tRPC organization.getCurrentOrganization
    throw new Error('PlatformClient.getOrganization() not yet implemented');
  }
}
