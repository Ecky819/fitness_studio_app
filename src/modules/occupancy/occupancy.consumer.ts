import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import Redis from 'ioredis';
import { OccupancyService } from './occupancy.service';

/**
 * Consumes gym_events:{tenantId} Redis Streams and updates occupancy counters.
 *
 * This decouples the AccessService from OccupancyService entirely.
 * AccessService writes to the stream; this consumer reads and reacts.
 *
 * The consumer runs in the same process but could trivially be extracted into
 * a separate worker for horizontal scaling (Phase 4+ / Enterprise plan).
 *
 * Stream key pattern: gym_events:{tenantId}
 * Entry fields: type, userId, doorId, reason, ts
 */
@Injectable()
export class OccupancyConsumer implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OccupancyConsumer.name);
  private readonly GROUP = 'occupancy-group';
  private readonly CONSUMER = 'occupancy-worker-1';
  private isRunning = false;

  constructor(
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
    private readonly occupancyService: OccupancyService,
  ) {}

  onModuleInit() {
    this.isRunning = true;
    void this.poll();
  }

  onModuleDestroy() {
    this.isRunning = false;
  }

  private async poll() {
    while (this.isRunning) {
      try {
        await this.consumeActive();
      } catch (err) {
        this.logger.error('Stream consumer error', err);
      }
      await new Promise((r) => setTimeout(r, 500)); // 500 ms poll interval
    }
  }

  private async consumeActive() {
    // Discover active tenants by scanning stream keys
    const keys = await this.redis.keys('gym_events:*');
    if (!keys.length) return;

    for (const streamKey of keys) {
      const tenantId = streamKey.replace('gym_events:', '');
      await this.ensureGroup(streamKey);

      const results = await this.redis.xreadgroup(
        'GROUP', this.GROUP, this.CONSUMER,
        'COUNT', '10',
        'BLOCK', '100',
        'STREAMS', streamKey, '>',
      ) as Array<[string, Array<[string, string[]]>]> | null;

      if (!results) continue;

      for (const [, entries] of results) {
        for (const [id, fields] of entries) {
          await this.processEntry(tenantId, fields);
          await this.redis.xack(streamKey, this.GROUP, id);
        }
      }
    }
  }

  private async processEntry(tenantId: string, fields: string[]) {
    // Redis XREADGROUP returns fields as flat [key, value, key, value, ...]
    const map: Record<string, string> = {};
    for (let i = 0; i < fields.length - 1; i += 2) {
      map[fields[i]] = fields[i + 1];
    }

    if (map.type === 'access_granted' && map.userId) {
      await this.occupancyService.recordEntry(tenantId, map.userId);
    }
  }

  private async ensureGroup(streamKey: string) {
    try {
      await this.redis.xgroup('CREATE', streamKey, this.GROUP, '$', 'MKSTREAM');
    } catch (err: any) {
      // BUSYGROUP = group already exists — ignore
      if (!err.message?.includes('BUSYGROUP')) {
        this.logger.warn(`xgroup create: ${err.message}`);
      }
    }
  }
}
