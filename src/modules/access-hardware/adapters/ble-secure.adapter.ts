import { Injectable, Logger } from '@nestjs/common';
import { IHardwareAdapter, UnlockParams, DoorStatus, WebhookResult } from '../hardware-adapter.interface';
import { MqttService } from '../../mqtt/mqtt.service';
import { PrismaService } from '../../../prisma/prisma.service';

/**
 * Adapter for own ESP32-based BLE door controllers.
 * Unlock is triggered via MQTT command; the device executes the relay.
 * The BLE Challenge/Response flow lives in AccessService and is used by
 * the mobile app — this adapter handles server-initiated unlocks (e.g. admin override).
 */
@Injectable()
export class BleSecureAdapter implements IHardwareAdapter {
  readonly name = 'ble-secure';
  private readonly logger = new Logger(BleSecureAdapter.name);

  constructor(
    private readonly mqtt: MqttService,
    private readonly prisma: PrismaService,
  ) {}

  async unlockDoor({ doorId, tenantId, userId, durationSeconds = 5 }: UnlockParams): Promise<void> {
    this.mqtt.publish(`gym/${tenantId}/door/${doorId}/command`, {
      action: 'unlock',
      durationSeconds,
      ...(userId ? { userId } : {}),
      ts: new Date().toISOString(),
    });
    this.logger.log(`BLE unlock command sent → ${tenantId}/${doorId}`);
  }

  async getDoorStatus(doorId: string, tenantId: string): Promise<DoorStatus> {
    const device = await this.prisma.device.findFirst({ where: { doorId, tenantId } });
    return {
      doorId,
      isOnline: device?.isOnline ?? false,
      isLocked: true,  // BLE devices don't report lock state over MQTT currently
      lastSeenAt: device?.lastSeenAt ?? undefined,
    };
  }

  async handleWebhook(_payload: unknown, _signature: string): Promise<WebhookResult> {
    // Own hardware doesn't use webhooks — events arrive via MQTT.
    return { handled: false };
  }
}
