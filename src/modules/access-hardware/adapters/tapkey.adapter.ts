import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'crypto';
import { IHardwareAdapter, UnlockParams, DoorStatus, WebhookResult } from '../hardware-adapter.interface';

const TAPKEY_API = 'https://my.tapkey.com/api/v1';

/**
 * Tapkey adapter.
 * Docs: https://developers.tapkey.io/api/
 *
 * Tapkey primarily works via BLE (phone→lock). Server-side unlock is triggered
 * via the Tapkey Management API (issues a one-time credential).
 *
 * Required env vars:
 *   TAPKEY_CLIENT_ID
 *   TAPKEY_CLIENT_SECRET
 *   TAPKEY_WEBHOOK_SECRET
 *
 * Tapkey lock IDs stored as "tapkey:{boundLockId}" in Device.doorId.
 */
@Injectable()
export class TapkeyAdapter implements IHardwareAdapter {
  readonly name = 'tapkey';
  private readonly logger = new Logger(TapkeyAdapter.name);
  private accessToken: string | null = null;
  private tokenExpiresAt = 0;

  constructor(private readonly config: ConfigService) {}

  async unlockDoor({ doorId, userId }: UnlockParams): Promise<void> {
    const lockId = this.extractId(doorId);
    const token = await this.getToken();

    // Tapkey: grant a short-lived (30s) physical-web credential, which triggers unlock
    const res = await fetch(`${TAPKEY_API}/owners/me/physicalLocks/${lockId}/grants`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        userId,
        validFrom: new Date().toISOString(),
        validBefore: new Date(Date.now() + 30_000).toISOString(),
        timeRestrictionIcal: null,
      }),
    });

    if (!res.ok) {
      const body = await res.text();
      this.logger.error(`Tapkey unlock failed: ${res.status} ${body}`);
      throw new Error(`Tapkey unlock failed: ${res.status}`);
    }
    this.logger.log(`Tapkey credential issued → lock ${lockId}`);
  }

  async getDoorStatus(doorId: string): Promise<DoorStatus> {
    const lockId = this.extractId(doorId);
    const token = await this.getToken();

    const res = await fetch(`${TAPKEY_API}/owners/me/physicalLocks/${lockId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });

    if (!res.ok) return { doorId, isOnline: false, isLocked: true };

    const data = (await res.json()) as { online: boolean; locked: boolean };
    return {
      doorId,
      isOnline: data.online ?? false,
      isLocked: data.locked ?? true,
    };
  }

  async handleWebhook(payload: unknown, signature: string): Promise<WebhookResult> {
    if (!this.verifySignature(payload, signature)) {
      throw new UnauthorizedException('Invalid Tapkey webhook signature');
    }

    const event = payload as { eventType: string; lockId: string };
    this.logger.log(`Tapkey webhook: ${event.eventType} lock=${event.lockId}`);

    return {
      handled: true,
      event: event.eventType,
      doorId: `tapkey:${event.lockId}`,
    };
  }

  private async getToken(): Promise<string> {
    if (this.accessToken && Date.now() < this.tokenExpiresAt - 30_000) {
      return this.accessToken;
    }

    const res = await fetch('https://login.tapkey.com/connect/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: this.config.get('TAPKEY_CLIENT_ID') ?? '',
        client_secret: this.config.get('TAPKEY_CLIENT_SECRET') ?? '',
        scope: 'register:mobiles read:core:entities handle:core:commands',
      }),
    });

    const data = (await res.json()) as { access_token: string; expires_in: number };
    this.accessToken = data.access_token;
    this.tokenExpiresAt = Date.now() + data.expires_in * 1000;
    return this.accessToken;
  }

  private extractId(doorId: string): string {
    return doorId.startsWith('tapkey:') ? doorId.slice(7) : doorId;
  }

  private verifySignature(payload: unknown, signature: string): boolean {
    const secret = this.config.get<string>('TAPKEY_WEBHOOK_SECRET') ?? '';
    if (!secret) return false;
    const expected = createHmac('sha256', secret)
      .update(JSON.stringify(payload))
      .digest('hex');
    return expected === signature;
  }
}
