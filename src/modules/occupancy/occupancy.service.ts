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

    // React to AI camera occupancy counts from MQTT
    this.mqttService.onCameraOccupancy((tenantId, cameraId, event) => {
      void this.recordCameraCount(tenantId, cameraId, event.count);
    });
  }

  setGateway(gw: OccupancyGateway) {
    this.gateway = gw;
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /**
   * Called when an AI camera reports its current people-count.
   * Replaces the Redis counter with the camera's absolute reading.
   * The camera is the ground truth; door-based counting is additive but the
   * camera overrides with a more accurate snapshot.
   */
  async recordCameraCount(tenantId: string, cameraId: string, count: number) {
    const key = `occupancy:entries:${tenantId}`;
    const now = Date.now();
    const expireAt = now + this.visitDurationMin * 60 * 1000;

    // Replace the sorted set with `count` synthetic entries so existing live-
    // count reads stay consistent. Use camera-prefixed members to distinguish
    // from door-entry members.
    const pipe = this.redis.pipeline();
    pipe.zremrangebyscore(key, '-inf', now);   // prune expired first
    const currentCount = await this.redis.zcard(key);

    if (count > currentCount) {
      // Add synthetic entries to make up the delta
      const newMembers: (string | number)[] = [];
      for (let i = 0; i < count - currentCount; i++) {
        newMembers.push(expireAt, `cam:${cameraId}:${now + i}`);
      }
      pipe.zadd(key, ...newMembers);
    } else if (count < currentCount) {
      // Remove excess synthetic camera entries (oldest first)
      pipe.zpopmin(key, currentCount - count);
    }
    await pipe.exec();

    const liveCount = await this.getLiveCount(tenantId);
    this.gateway?.broadcast(tenantId, liveCount);
    await this.checkCapacityAlert(tenantId, liveCount);

    this.logger.debug(`Camera ${cameraId} → ${count} people in ${tenantId}`);
  }

  /** Called by AccessService on every GRANTED event. */
  async recordEntry(tenantId: string, userId?: string) {
    const now = Date.now();
    const expireAt = now + this.visitDurationMin * 60 * 1000;

    const member = userId ?? `anon:${now}`;
    await this.redis.zadd(`occupancy:entries:${tenantId}`, expireAt, member);

    const count = await this.getLiveCount(tenantId);
    this.gateway?.broadcast(tenantId, count);
    await this.checkCapacityAlert(tenantId, count);
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

  async getHeatmap(tenantId: string, days = 28) {
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const snapshots = await this.prisma.occupancySnapshot.findMany({
      where: { tenantId, recordedAt: { gte: since } },
      select: { count: true, recordedAt: true },
    });

    // 7 rows (Mon=0 … Sun=6) × 24 columns (hour 0–23)
    const sums = Array.from({ length: 7 }, () => new Array<number>(24).fill(0));
    const cnts = Array.from({ length: 7 }, () => new Array<number>(24).fill(0));

    for (const s of snapshots) {
      const d = new Date(s.recordedAt);
      const dow = (d.getDay() + 6) % 7; // JS Sun=0 → Mon=0
      const hour = d.getHours();
      sums[dow][hour] += s.count;
      cnts[dow][hour]++;
    }

    const heatmap = sums.map((row, dow) =>
      row.map((sum, hour) => ({
        day: dow,
        hour,
        avg: cnts[dow][hour] > 0 ? Math.round(sum / cnts[dow][hour]) : 0,
      })),
    );

    return { heatmap, days, generatedAt: new Date().toISOString() };
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

  private async checkCapacityAlert(tenantId: string, count: number) {
    const config = await this.prisma.tenantConfig.findUnique({
      where: { tenantId },
      select: { features: true },
    });
    const features = (config?.features as Record<string, unknown>) ?? {};
    const capacity = (features['GYM_CAPACITY'] as number) ?? this.defaultCapacity;
    const alertThresholdPct = (features['ALERT_THRESHOLD_PCT'] as number) ?? 80;
    const pct = Math.round((count / capacity) * 100);

    if (pct >= alertThresholdPct) {
      // Throttle: fire at most once per 15 minutes per tenant
      const throttleKey = `capacity:alert:${tenantId}`;
      if (!(await this.redis.get(throttleKey))) {
        await this.redis.setex(throttleKey, 900, '1');
        this.gateway?.broadcastCapacityAlert(tenantId, count, capacity, pct);
        this.logger.warn(`Capacity alert: ${tenantId} at ${pct}% (${count}/${capacity})`);
      }
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
