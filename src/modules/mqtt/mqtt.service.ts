import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as mqtt from 'mqtt';
import { PrismaService } from '../../prisma/prisma.service';

export interface MqttDoorEvent {
  type: 'access_granted' | 'access_denied' | 'heartbeat' | 'door_open' | 'door_closed';
  userId?: string;
  reason?: string;
  timestamp: string;
  firmwareVersion?: string;
}

export interface MqttOtaStatus {
  status: 'started' | 'progress' | 'success' | 'failed';
  version?: string;
  progress?: number; // 0–100
  error?: string;
  timestamp: string;
}

export interface MqttCameraOccupancy {
  count: number;
  confidence?: number; // 0–1
  timestamp: string;
}

/**
 * MQTT service — connects to the external broker as a subscriber.
 *
 * Topic conventions:
 *   gym/{tenantId}/door/{doorId}/event     → access events from physical doors
 *   gym/{tenantId}/door/{doorId}/heartbeat → device heartbeat (online check)
 *
 * This service:
 *   1. Keeps device `isOnline` / `lastSeenAt` up to date in real time
 *   2. Fires the OccupancyService hook on access events
 *   3. Publishes events to Redis Streams for the AI pipeline
 *
 * If no MQTT_BROKER_URL is configured the service starts in no-op mode
 * (safe for dev environments without a broker).
 */
@Injectable()
export class MqttService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MqttService.name);
  private client: mqtt.MqttClient | null = null;

  // Callbacks registered by other services (OccupancyService etc.)
  private readonly accessListeners: Array<
    (tenantId: string, doorId: string, event: MqttDoorEvent) => void
  > = [];

  private readonly otaListeners: Array<
    (tenantId: string, doorId: string, status: MqttOtaStatus) => void
  > = [];

  private readonly cameraListeners: Array<
    (tenantId: string, cameraId: string, event: MqttCameraOccupancy) => void
  > = [];

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  onModuleInit() {
    const brokerUrl = this.configService.get<string>('MQTT_BROKER_URL');
    if (!brokerUrl) {
      this.logger.warn('MQTT_BROKER_URL not set — running in no-op mode');
      return;
    }

    this.client = mqtt.connect(brokerUrl, {
      clientId: this.configService.get<string>('MQTT_CLIENT_ID') ?? 'gym-os-backend',
      username: this.configService.get<string>('MQTT_USERNAME'),
      password: this.configService.get<string>('MQTT_PASSWORD'),
      reconnectPeriod: 5000,
      connectTimeout: 10_000,
      clean: true,
    });

    this.client.on('connect', () => {
      this.logger.log('MQTT broker connected');
      this.client!.subscribe('gym/+/door/+/event');
      this.client!.subscribe('gym/+/door/+/heartbeat');
      this.client!.subscribe('gym/+/door/+/ota/status');   // OTA update reports
      this.client!.subscribe('gym/+/camera/+/occupancy'); // AI camera counts
    });

    this.client.on('message', (topic, payload) => {
      void this.handleMessage(topic, payload);
    });

    this.client.on('error', (err) => this.logger.error('MQTT error', err));
    this.client.on('reconnect', () => this.logger.warn('MQTT reconnecting…'));
    this.client.on('offline', () => this.logger.warn('MQTT offline'));
  }

  onModuleDestroy() {
    this.client?.end(true);
  }

  /** Publish a message to the broker (used for server→device commands). */
  publish(topic: string, payload: Record<string, unknown>) {
    if (!this.client?.connected) return;
    this.client.publish(topic, JSON.stringify(payload), { qos: 1 });
  }

  /** Register a callback for access events — called by OccupancyService. */
  onAccessEvent(
    cb: (tenantId: string, doorId: string, event: MqttDoorEvent) => void,
  ) {
    this.accessListeners.push(cb);
  }

  /** Register a callback for OTA status events — called by DeviceProvisioning or admin. */
  onOtaStatus(
    cb: (tenantId: string, doorId: string, status: MqttOtaStatus) => void,
  ) {
    this.otaListeners.push(cb);
  }

  /** Register a callback for camera occupancy events — called by OccupancyService. */
  onCameraOccupancy(
    cb: (tenantId: string, cameraId: string, event: MqttCameraOccupancy) => void,
  ) {
    this.cameraListeners.push(cb);
  }

  // ── Private ─────────────────────────────────────────────────────────────────

  private async handleMessage(topic: string, payload: Buffer) {
    const parts = topic.split('/');
    if (parts.length < 5 || parts[0] !== 'gym') return;

    const [, tenantId, deviceClass, deviceId, ...rest] = parts;
    const channel = rest.join('/'); // handles multi-level channels like "ota/status"

    let body: unknown;
    try {
      body = JSON.parse(payload.toString());
    } catch {
      this.logger.warn(`Malformed MQTT payload on ${topic}`);
      return;
    }

    if (deviceClass === 'door') {
      await this.handleDoorMessage(tenantId, deviceId, channel, body as MqttDoorEvent);
    } else if (deviceClass === 'camera' && channel === 'occupancy') {
      this.cameraListeners.forEach((cb) =>
        cb(tenantId, deviceId, body as MqttCameraOccupancy),
      );
    }
  }

  private async handleDoorMessage(
    tenantId: string,
    doorId: string,
    channel: string,
    body: MqttDoorEvent,
  ) {
    if (channel === 'heartbeat') {
      await this.prisma.device.updateMany({
        where: { doorId, tenantId },
        data: {
          isOnline: true,
          lastSeenAt: new Date(),
          ...(body.firmwareVersion ? { firmwareVersion: body.firmwareVersion } : {}),
        },
      });
      return;
    }

    if (channel === 'event') {
      this.accessListeners.forEach((cb) => cb(tenantId, doorId, body));
      return;
    }

    if (channel === 'ota/status') {
      const status = body as unknown as MqttOtaStatus;
      this.logger.log(`OTA status ${tenantId}/${doorId}: ${status.status} v${status.version ?? '?'}`);

      if (status.status === 'success' && status.version) {
        await this.prisma.device.updateMany({
          where: { doorId, tenantId },
          data: { firmwareVersion: status.version },
        });
      }

      this.otaListeners.forEach((cb) => cb(tenantId, doorId, status));
    }
  }
}
