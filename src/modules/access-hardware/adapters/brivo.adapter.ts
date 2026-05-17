import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'crypto';
import { IHardwareAdapter, UnlockParams, DoorStatus, WebhookResult } from '../hardware-adapter.interface';

const BRIVO_API = 'https://auth.brivo.com/oauth/token';
const BRIVO_ONAIR = 'https://api.brivo.com/v1/api';

/**
 * Brivo OnAir adapter.
 * Docs: https://developer.brivo.com/
 *
 * Required env vars:
 *   BRIVO_CLIENT_ID     — OAuth2 client credentials
 *   BRIVO_CLIENT_SECRET
 *   BRIVO_API_KEY       — Brivo API key (x-api-key header)
 *   BRIVO_WEBHOOK_SECRET
 *
 * Brivo access point IDs are stored as "brivo:{id}" in Device.doorId.
 */
@Injectable()
export class BrivoAdapter implements IHardwareAdapter {
  readonly name = 'brivo';
  private readonly logger = new Logger(BrivoAdapter.name);
  private accessToken: string | null = null;
  private tokenExpiresAt = 0;

  constructor(private readonly config: ConfigService) {}

  async unlockDoor({ doorId }: UnlockParams): Promise<void> {
    const pointId = this.extractId(doorId);
    const token = await this.getToken();

    const res = await fetch(`${BRIVO_ONAIR}/access-points/${pointId}/unlock`, {
      method: 'PUT',
      headers: this.headers(token),
    });

    if (!res.ok) {
      const body = await res.text();
      this.logger.error(`Brivo unlock failed: ${res.status} ${body}`);
      throw new Error(`Brivo unlock failed: ${res.status}`);
    }
    this.logger.log(`Brivo unlock OK → access point ${pointId}`);
  }

  async getDoorStatus(doorId: string): Promise<DoorStatus> {
    const pointId = this.extractId(doorId);
    const token = await this.getToken();

    const res = await fetch(`${BRIVO_ONAIR}/access-points/${pointId}`, {
      headers: this.headers(token),
    });

    if (!res.ok) {
      return { doorId, isOnline: false, isLocked: true };
    }

    const data = (await res.json()) as { locked: boolean; connected: boolean };
    return {
      doorId,
      isOnline: data.connected ?? false,
      isLocked: data.locked ?? true,
    };
  }

  async handleWebhook(payload: unknown, signature: string): Promise<WebhookResult> {
    if (!this.verifySignature(payload, signature)) {
      throw new UnauthorizedException('Invalid Brivo webhook signature');
    }

    const event = payload as { eventType: string; accessPointId: string };
    this.logger.log(`Brivo webhook: ${event.eventType} ap=${event.accessPointId}`);

    return {
      handled: true,
      event: event.eventType,
      doorId: `brivo:${event.accessPointId}`,
    };
  }

  private async getToken(): Promise<string> {
    if (this.accessToken && Date.now() < this.tokenExpiresAt - 30_000) {
      return this.accessToken;
    }

    const res = await fetch(BRIVO_API, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: this.config.get('BRIVO_CLIENT_ID') ?? '',
        client_secret: this.config.get('BRIVO_CLIENT_SECRET') ?? '',
      }),
    });

    const data = (await res.json()) as { access_token: string; expires_in: number };
    this.accessToken = data.access_token;
    this.tokenExpiresAt = Date.now() + data.expires_in * 1000;
    return this.accessToken;
  }

  private headers(token: string) {
    return {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      'x-api-key': this.config.get<string>('BRIVO_API_KEY') ?? '',
    };
  }

  private extractId(doorId: string): string {
    return doorId.startsWith('brivo:') ? doorId.slice(6) : doorId;
  }

  private verifySignature(payload: unknown, signature: string): boolean {
    const secret = this.config.get<string>('BRIVO_WEBHOOK_SECRET') ?? '';
    if (!secret) return false;
    const expected = createHmac('sha256', secret)
      .update(JSON.stringify(payload))
      .digest('hex');
    return expected === signature;
  }
}
