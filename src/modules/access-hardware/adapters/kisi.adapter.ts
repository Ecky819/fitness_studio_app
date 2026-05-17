import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'crypto';
import { IHardwareAdapter, UnlockParams, DoorStatus, WebhookResult } from '../hardware-adapter.interface';

const KISI_API = 'https://api.kisi.io';

/**
 * Kisi hardware adapter.
 * Docs: https://api.kisi.io/docs
 *
 * Required env vars:
 *   KISI_API_KEY        — your Kisi API key (Bearer token)
 *   KISI_WEBHOOK_SECRET — used to verify inbound Kisi webhook signatures
 *
 * Kisi lock IDs are stored in Device.doorId with prefix "kisi:" (e.g. "kisi:42").
 */
@Injectable()
export class KisiAdapter implements IHardwareAdapter {
  readonly name = 'kisi';
  private readonly logger = new Logger(KisiAdapter.name);
  private readonly apiKey: string;
  private readonly webhookSecret: string;

  constructor(private readonly config: ConfigService) {
    this.apiKey = config.get<string>('KISI_API_KEY') ?? '';
    this.webhookSecret = config.get<string>('KISI_WEBHOOK_SECRET') ?? '';
  }

  async unlockDoor({ doorId }: UnlockParams): Promise<void> {
    const lockId = this.extractId(doorId);
    const res = await fetch(`${KISI_API}/locks/${lockId}/unlock`, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify({}),
    });

    if (!res.ok) {
      const body = await res.text();
      this.logger.error(`Kisi unlock failed: ${res.status} ${body}`);
      throw new Error(`Kisi unlock failed: ${res.status}`);
    }
    this.logger.log(`Kisi unlock OK → lock ${lockId}`);
  }

  async getDoorStatus(doorId: string): Promise<DoorStatus> {
    const lockId = this.extractId(doorId);
    const res = await fetch(`${KISI_API}/locks/${lockId}`, { headers: this.headers() });

    if (!res.ok) {
      return { doorId, isOnline: false, isLocked: true };
    }

    const data = (await res.json()) as { locked: boolean; online: boolean };
    return {
      doorId,
      isOnline: data.online ?? false,
      isLocked: data.locked ?? true,
    };
  }

  async handleWebhook(payload: unknown, signature: string): Promise<WebhookResult> {
    if (!this.verifySignature(payload, signature)) {
      throw new UnauthorizedException('Invalid Kisi webhook signature');
    }

    const event = payload as { event: string; lock_id: number; place_id: number };
    this.logger.log(`Kisi webhook: ${event.event} lock=${event.lock_id}`);

    return {
      handled: true,
      event: event.event,
      doorId: `kisi:${event.lock_id}`,
    };
  }

  private headers() {
    return {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${this.apiKey}`,
    };
  }

  private extractId(doorId: string): string {
    // doorId format: "kisi:42" → "42"
    return doorId.startsWith('kisi:') ? doorId.slice(5) : doorId;
  }

  private verifySignature(payload: unknown, signature: string): boolean {
    if (!this.webhookSecret) return false;
    const expected = createHmac('sha256', this.webhookSecret)
      .update(JSON.stringify(payload))
      .digest('hex');
    return expected === signature;
  }
}
