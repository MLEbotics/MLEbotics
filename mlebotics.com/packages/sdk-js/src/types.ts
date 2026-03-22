/** Auth options for the PlatformClient */
export interface PlatformClientOptions {
  /** Base URL of the MLEbotics platform API, e.g. https://app.mlebotics.com/api */
  baseUrl: string;
  /** API key for server-to-server authentication */
  apiKey?: string;
  /** Bearer token for user-session authentication */
  token?: string;
}

export interface HealthResponse {
  status: 'ok';
  timestamp: string;
}

export interface UserProfile {
  id: string;
  email: string;
  name: string | null;
  avatarUrl: string | null;
}

export interface Organization {
  id: string;
  name: string;
  slug: string;
  avatarUrl: string | null;
}

export interface SDKError {
  code: string;
  message: string;
  status?: number;
}
