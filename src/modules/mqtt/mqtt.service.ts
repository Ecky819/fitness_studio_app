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
      // Subscribe to all tenants / all doors
      this.client!.subscribe('gym/+/door/+/event');
      this.client!.subscribe('gym/+/door/+/heartbeat');
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

  // ── Private ─────────────────────────────────────────────────────────────────

  private async handleMessage(topic: string, payload: Buffer) {
    // Parse topic: gym/{tenantId}/door/{doorId}/{channel}
    const parts = topic.split('/');
    if (parts.length < 5 || parts[0] !== 'gym') return;

    const [, tenantId, , doorId, channel] = parts;
    let body: MqttDoorEvent;

    try {
      body = JSON.parse(payload.toString()) as MqttDoorEvent;
    } catch {
      this.logger.warn(`Malformed MQTT payload on ${topic}`);
      return;
    }

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
      // Notify listeners (OccupancyService etc.)
      this.accessListeners.forEach((cb) => cb(tenantId, doorId, body));
    }
  }
}
