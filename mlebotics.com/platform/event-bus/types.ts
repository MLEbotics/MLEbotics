import type { ID, Timestamp } from '../shared/types';

// ─── Event Types ─────────────────────────────────────────────────────────────

export type EventType =
  // World engine events
  | 'world.entity.created'
  | 'world.entity.updated'
  | 'world.entity.removed'
  | 'world.stream.started'
  | 'world.stream.stopped'
  // Automation engine events
  | 'automation.workflow.started'
  | 'automation.workflow.completed'
  | 'automation.workflow.failed'
  | 'automation.step.started'
  | 'automation.step.completed'
  | 'automation.step.failed'
  // Robotics events
  | 'robotics.robot.connected'
  | 'robotics.robot.disconnected'
  | 'robotics.robot.telemetry'
  | 'robotics.command.sent'
  | 'robotics.command.completed'
  | 'robotics.command.failed'
  // Plugin events
  | 'plugin.installed'
  | 'plugin.uninstalled'
  | 'plugin.error'
  // System events
  | 'system.error'
  | 'system.warning';

// ─── Event Model ─────────────────────────────────────────────────────────────

export interface PlatformEvent<TPayload = unknown> {
  /** Unique event identifier */
  id: ID;
  /** Event type discriminator */
  type: EventType;
  /** Organization context for this event */
  organizationId: ID;
  /** ISO timestamp when the event was emitted */
  timestamp: Timestamp;
  /** Source that produced this event (engine name, adapter name, etc.) */
  source: string;
  /** Arbitrary payload — shape depends on event type */
  payload: TPayload;
}

// ─── Subscription Model ───────────────────────────────────────────────────────

export type EventHandler<TPayload = unknown> = (
  event: PlatformEvent<TPayload>
) => void | Promise<void>;

export interface EventSubscription {
  /** Unique subscription handle — use to unsubscribe */
  id: ID;
  /** The event type(s) this subscription listens to */
  types: EventType[];
}

// ─── EventBus Interface ───────────────────────────────────────────────────────

export interface IEventBus {
  /**
   * Subscribe to one or more event types.
   * Returns a subscription handle that can be used to unsubscribe.
   */
  subscribe<TPayload = unknown>(
    types: EventType[],
    handler: EventHandler<TPayload>
  ): EventSubscription;

  /** Remove a previously registered subscription */
  unsubscribe(subscriptionId: ID): void;

  /** Emit an event to all matching subscribers */
  emit<TPayload = unknown>(event: Omit<PlatformEvent<TPayload>, 'id' | 'timestamp'>): void;
}
