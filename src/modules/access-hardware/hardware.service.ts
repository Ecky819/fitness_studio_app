import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { IHardwareAdapter, UnlockParams, DoorStatus, WebhookResult } from './hardware-adapter.interface';
import { BleSecureAdapter } from './adapters/ble-secure.adapter';
import { KisiAdapter } from './adapters/kisi.adapter';
import { BrivoAdapter } from './adapters/brivo.adapter';
import { TapkeyAdapter } from './adapters/tapkey.adapter';

/**
 * Selects the correct hardware adapter at runtime.
 *
 * Resolution order:
 *   1. Device.hardwareAdapter (per-device override)
 *   2. TenantConfig.hardwareAdapter (tenant-wide default)
 *   3. "ble-secure" (global fallback)
 */
@Injectable()
export class HardwareService {
  private readonly logger = new Logger(HardwareService.name);
  private readonly adapters: Map<string, IHardwareAdapter>;

  constructor(
    private readonly prisma: PrismaService,
    ble: BleSecureAdapter,
    kisi: KisiAdapter,
    brivo: BrivoAdapter,
    tapkey: TapkeyAdapter,
  ) {
    this.adapters = new Map<string, IHardwareAdapter>([
      [ble.name, ble],
      [kisi.name, kisi],
      [brivo.name, brivo],
      [tapkey.name, tapkey],
    ]);
  }

  /** Resolve the adapter for a specific door in a tenant. */
  async resolveAdapter(doorId: string, tenantId: string): Promise<IHardwareAdapter> {
    const device = await this.prisma.device.findFirst({ where: { doorId, tenantId } });
    const config = await this.prisma.tenantConfig.findUnique({ where: { tenantId } });

    const adapterName =
      device?.hardwareAdapter ??
      config?.hardwareAdapter ??
      'ble-secure';

    const adapter = this.adapters.get(adapterName);
    if (!adapter) {
      this.logger.warn(`Unknown hardware adapter "${adapterName}", falling back to ble-secure`);
      return this.adapters.get('ble-secure')!;
    }
    return adapter;
  }

  async unlockDoor(params: UnlockParams): Promise<void> {
    const adapter = await this.resolveAdapter(params.doorId, params.tenantId);
    this.logger.log(`Unlock via ${adapter.name} → ${params.doorId}`);
    return adapter.unlockDoor(params);
  }

  async getDoorStatus(doorId: string, tenantId: string): Promise<DoorStatus> {
    const adapter = await this.resolveAdapter(doorId, tenantId);
    return adapter.getDoorStatus(doorId, tenantId);
  }

  async handleWebhook(
    adapterName: string,
    payload: unknown,
    signature: string,
  ): Promise<WebhookResult> {
    const adapter = this.adapters.get(adapterName);
    if (!adapter) throw new NotFoundException(`No adapter named "${adapterName}"`);
    return adapter.handleWebhook(payload, signature);
  }

  /** List all registered adapter names (for admin UI). */
  listAdapters(): string[] {
    return [...this.adapters.keys()];
  }
}
