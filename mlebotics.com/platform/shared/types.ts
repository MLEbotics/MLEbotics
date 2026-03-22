// platform/shared/types.ts
// Shared primitives used across all platform engines

export interface PaginatedResult<T> {
  data:       T[]
  total:      number
  page:       number
  pageSize:   number
  hasMore:    boolean
}

export interface ApiError {
  code:     string
  message:  string
  details?: Record<string, unknown>
}

export type ID = string  // cuid / uuid — all IDs are strings platform-wide

export type Timestamp = Date | string

export interface AuditEvent {
  id:        ID
  orgId:     ID
  userId:    ID
  action:    string
  resource:  string
  resourceId: ID
  metadata:  Record<string, unknown>
  createdAt: Timestamp
}
