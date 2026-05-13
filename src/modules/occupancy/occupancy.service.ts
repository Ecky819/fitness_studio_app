import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import Redis from 'ioredis';
import { PrismaService } from '../../prisma/prisma.service';
import { MqttService } from '../mqtt/mqtt.service';
import { OccupancyGateway } from './occupancy.gateway';

/**
 * Occupancy tracks the estimated number of people currently inside each gym.
 *
 * Real-time counter lives in Redis: `occupancy:{tenantId}`.
 * Incremented on every GRANTED access event; decremented by the background job
 * that expires visits older than OCCUPANCY_VISIT_DURATION_MIN.
 *
 * Live count is broadcast via WebSocket whenever it changes.
 * Every 15 minutes a snapshot is archived to PostgreSQL for historical charts.
 *
 * The count is intentionally approximate — it measures check-INs without
 * requiring an explicit check-OUT, relying on time-based decay instead.
 */
@Injectable()
export class OccupancyService implements OnModuleInit {
  private readonly logger = new Logger(OccupancyService.name);
  private readonly visitDurationMin: number;
  private readonly defaultCapacity: number;
  private gateway!: OccupancyGateway; // set via setGateway to avoid circular dep

  constructor(
    private readonly prisma: PrismaService,
    private readonly configService: ConfigService,
    private readonly mqttService: MqttService,
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
  ) {
    this.visitDurationMin =
      Number(this.configService.get('OCCUPANCY_VISIT_DURATION_MIN')) || 90;
    this.defaultCapacity =
      Number(this.configService.get('DEFAULT_GYM_CAPACITY')) || 50;
  }

  onModuleInit() {
    // React to physical door events from MQTT
    this.mqttService.onAccessEvent((tenantId, _doorId, event) => {
      if (event.type === 'access_granted') {
        void this.recordEntry(tenantId, event.userId);
      }
    });
  }

  setGateway(gw: OccupancyGateway) {
    this.gateway = gw;
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /** Called by AccessService on every GRANTED event. */
  async recordEntry(tenantId: string, userId?: string) {
    const now = Date.now();
    const expireAt = now + this.visitDurationMin * 60 * 1000;

    // Store entry as a sorted set member: score = expireAt, member = userId|nonce
    const member = userId ?? `anon:${now}`;
    await this.redis.zadd(`occupancy:entries:${tenantId}`, expireAt, member);

    const count = await this.getLiveCount(tenantId);
    this.gateway?.broadcast(tenantId, count);
  }

  async getLiveCount(tenantId: string): Promise<number> {
    // Prune expired entries first (score < now)
    await this.redis.zremrangebyscore(
      `occupancy:entries:${tenantId}`,
      '-inf',
      Date.now(),
    );
    return this.redis.zcard(`occupancy:entries:${tenantId}`);
  }

  async getCurrentOccupancy(tenantId: string) {
    const count = await this.getLiveCount(tenantId);
    const config = await this.prisma.tenantConfig.findUnique({
      where: { tenantId },
      select: { features: true },
    });

    const features = (config?.features as Record<string, unknown>) ?? {};
    const capacity =
      (features['GYM_CAPACITY'] as number | undefined) ?? this.defaultCapacity;

    return {
      tenantId,
      count,
      capacity,
      percentage: Math.round((count / capacity) * 100),
      updatedAt: new Date().toISOString(),
    };
  }

  async getOccupancyHistory(tenantId: string, hours = 24) {
    const since = new Date(Date.now() - hours * 60 * 60 * 1000);

    const snapshots = await this.prisma.occupancySnapshot.findMany({
      where: { tenantId, recordedAt: { gte: since } },
      orderBy: { recordedAt: 'asc' },
      select: { count: true, capacity: true, recordedAt: true },
    });

    return snapshots.map((s) => ({
      count: s.count,
      capacity: s.capacity,
      timestamp: s.recordedAt.toISOString(),
    }));
  }

  // ── Background Jobs ─────────────────────────────────────────────────────────

  /** Archive occupancy snapshots every 15 minutes */
  @Cron('0 */15 * * * *')
  async archiveSnapshots() {
    const tenants = await this.prisma.tenant.findMany({
      where: { status: 'ACTIVE' },
      select: { id: true, config: { select: { features: true } } },
    });

    for (const tenant of tenants) {
      const count = await this.getLiveCount(tenant.id);
      const features = (tenant.config?.features as Record<string, unknown>) ?? {};
      const capacity =
        (features['GYM_CAPACITY'] as number | undefined) ?? this.defaultCapacity;

      await this.prisma.occupancySnapshot.create({
        data: { tenantId: tenant.id, count, capacity },
      });
    }
  }

  /** Broadcast current counts to all connected WebSocket clients every minute */
  @Cron(CronExpression.EVERY_MINUTE)
  async broadcastAll() {
    const tenants = await this.prisma.tenant.findMany({
      where: { status: 'ACTIVE' },
      select: { id: true },
    });

    for (const { id } of tenants) {
      const count = await this.getLiveCount(id);
      this.gateway?.broadcast(id, count);
    }
  }
}
