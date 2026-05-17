export interface UnlockParams {
  doorId: string;
  tenantId: string;
  userId?: string;
  durationSeconds?: number;
}

export interface DoorStatus {
  doorId: string;
  isOnline: boolean;
  isLocked: boolean;
  lastSeenAt?: Date;
}

export interface WebhookResult {
  handled: boolean;
  event?: string;
  doorId?: string;
  tenantId?: string;
}

/**
 * Common interface every hardware adapter must implement.
 * Each provider (Kisi, Brivo, Tapkey, own BLE) gets one adapter class.
 * HardwareService selects the right one at runtime based on TenantConfig.
 */
export interface IHardwareAdapter {
  /** Unique identifier stored in TenantConfig.hardwareAdapter / Device.hardwareAdapter */
  readonly name: string;

  /** Trigger a door unlock. Resolves when the command is accepted (not when door opens). */
  unlockDoor(params: UnlockParams): Promise<void>;

  /** Fetch the real-time status of a single door. */
  getDoorStatus(doorId: string, tenantId: string): Promise<DoorStatus>;

  /** Process an inbound webhook payload from the provider. */
  handleWebhook(payload: unknown, signature: string): Promise<WebhookResult>;
}
