import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { BatchSyncDto, EdgeEventType } from './dto/edge.dto';

export interface EdgeSyncJobData {
  edgeSyncEventId: string;
}

export interface BatchSyncResult {
  accepted: number;
  duplicate: number;
  queued: number;
}

@Injectable()
export class EdgeService {
  private readonly logger = new Logger(EdgeService.name);
  private readonly MAX_BATCH_SIZE = 500;
  private readonly MAX_RETRY_COUNT = 3;

  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue('edge-sync') private readonly edgeQueue: Queue,
  ) {}

  // ── Batch ingestion ───────────────────────────────────────────────────────

  /**
   * Accepts a batch of offline events from an edge device.
   * Each event is stored with its idempotencyKey; duplicates are silently skipped.
   * New events are immediately queued for async processing.
   */
  async batchSync(
    deviceId: string,
    tenantId: string,
    dto: BatchSyncDto,
  ): Promise<BatchSyncResult> {
    const events = dto.events.slice(0, this.MAX_BATCH_SIZE);
    let accepted = 0;
    let duplicate = 0;

    const existing = await this.prisma.edgeSyncEvent.findMany({
      where: { idempotencyKey: { in: events.map((e) => e.idempotencyKey) } },
      select: { idempotencyKey: true },
    });
    const existingKeys = new Set(existing.map((e) => e.idempotencyKey));

    const newEvents = events.filter((e) => !existingKeys.has(e.idempotencyKey));
    duplicate = events.length - newEvents.length;

    if (newEvents.length > 0) {
      await this.prisma.edgeSyncEvent.createMany({
        data: newEvents.map((e) => ({
          tenantId,
          deviceId,
          idempotencyKey: e.idempotencyKey,
          eventType: e.eventType as any,
          payload: (e.payload ?? {}) as unknown as Prisma.InputJsonValue,
          occurredAt: new Date(e.occurredAt),
          status: 'PENDING' as any,
        })),
        skipDuplicates: true,
      });

      const created = await this.prisma.edgeSyncEvent.findMany({
        where: { idempotencyKey: { in: newEvents.map((e) => e.idempotencyKey) } },
        select: { id: true },
      });

      for (const { id } of created) {
        await this.edgeQueue.add('process-edge-event', { edgeSyncEventId: id });
      }

      accepted = newEvents.length;
    }

    this.logger.log(
      `[${tenantId}/${deviceId}] Sync: accepted=${accepted} duplicate=${duplicate} total=${events.length}`,
    );

    return { accepted, duplicate, queued: accepted };
  }

  // ── Event processing ──────────────────────────────────────────────────────

  /**
   * Processes a single buffered edge event. Called by the BullMQ processor.
   * Idempotency is guaranteed by the PENDING → PROCESSING → COMPLETED state machine.
   */
  async processEvent(edgeSyncEventId: string): Promise<void> {
    const event = await this.prisma.edgeSyncEvent.findUnique({
      where: { id: edgeSyncEventId },
    });

    if (!event) {
      this.logger.warn(`EdgeSyncEvent ${edgeSyncEventId} not found`);
      return;
    }

    if (event.status !== 'PENDING') {
      this.logger.debug(`EdgeSyncEvent ${edgeSyncEventId} already processed (${event.status})`);
      return;
    }

    await this.prisma.edgeSyncEvent.update({
      where: { id: edgeSyncEventId },
      data: { status: 'PROCESSING' },
    });

    try {
      switch (event.eventType as EdgeEventType) {
        case EdgeEventType.ACCESS_GRANTED:
          await this.processAccessGranted(event);
          break;
        case EdgeEventType.ACCESS_DENIED:
          await this.processAccessDenied(event);
          break;
        case EdgeEventType.DOOR_FORCED_OPEN:
        case EdgeEventType.DOOR_HELD_OPEN:
          await this.processDoorAlert(event);
          break;
        case EdgeEventType.DEVICE_REBOOTED:
        case EdgeEventType.FIRMWARE_UPDATED:
          await this.processDeviceLifecycle(event);
          break;
      }

      await this.prisma.edgeSyncEvent.update({
        where: { id: edgeSyncEventId },
        data: { status: 'COMPLETED', processedAt: new Date() },
      });
    } catch (err: any) {
      const nextRetry = event.retryCount + 1;
      await this.prisma.edgeSyncEvent.update({
        where: { id: edgeSyncEventId },
        data: {
          status: nextRetry >= this.MAX_RETRY_COUNT ? 'FAILED' : 'PENDING',
          retryCount: nextRetry,
          error: err.message,
        },
      });
      this.logger.error(`Failed to process EdgeSyncEvent ${edgeSyncEventId}: ${err.message}`);
      throw err; // BullMQ will retry
    }
  }

  // ── Status & Admin ────────────────────────────────────────────────────────

  async getSyncStatus(tenantId: string, deviceId?: string) {
    const where = { tenantId, ...(deviceId && { deviceId }) };
    const [pending, processing, completed, failed, duplicate] = await Promise.all([
      this.prisma.edgeSyncEvent.count({ where: { ...where, status: 'PENDING' } }),
      this.prisma.edgeSyncEvent.count({ where: { ...where, status: 'PROCESSING' } }),
      this.prisma.edgeSyncEvent.count({ where: { ...where, status: 'COMPLETED' } }),
      this.prisma.edgeSyncEvent.count({ where: { ...where, status: 'FAILED' } }),
      this.prisma.edgeSyncEvent.count({ where: { ...where, status: 'DUPLICATE' } }),
    ]);
    return { pending, processing, completed, failed, duplicate, total: pending + processing + completed + failed + duplicate };
  }

  /**
   * Re-queues FAILED events for retry. Returns the number of events re-queued.
   */
  async retryFailed(tenantId: string, deviceId?: string): Promise<number> {
    const where = {
      tenantId,
      status: 'FAILED' as any,
      ...(deviceId && { deviceId }),
    };

    const failed = await this.prisma.edgeSyncEvent.findMany({
      where,
      select: { id: true },
    });

    await this.prisma.edgeSyncEvent.updateMany({
      where,
      data: { status: 'PENDING', retryCount: 0, error: null },
    });

    for (const { id } of failed) {
      await this.edgeQueue.add('process-edge-event', { edgeSyncEventId: id });
    }

    return failed.length;
  }

  // ── Private processors ────────────────────────────────────────────────────

  private async processAccessGranted(event: any): Promise<void> {
    const payload = event.payload as Record<string, string>;
    const userId = payload.userId;
    const doorId = payload.doorId;

    if (!userId) return;

    // Find an active grant for this user
    const grant = await this.prisma.accessGrant.findFirst({
      where: { userId, active: true, validUntil: { gte: event.occurredAt } },
      orderBy: { createdAt: 'desc' },
    });

    await this.prisma.accessEvent.create({
      data: {
        userId,
        accessGrantId: grant?.id ?? await this.getFallbackGrantId(userId),
        doorId: doorId ?? null,
        status: 'GRANTED',
        reason: 'offline_replay',
        createdAt: event.occurredAt,
      },
    });

    this.logger.debug(`[Edge] Replayed ACCESS_GRANTED for user ${userId} at door ${doorId}`);
  }

  private async processAccessDenied(event: any): Promise<void> {
    const payload = event.payload as Record<string, string>;
    const userId = payload.userId;
    const doorId = payload.doorId;
    const reason = payload.reason ?? 'offline_denied';

    if (!userId) return;

    const grant = await this.prisma.accessGrant.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    if (!grant) return;

    await this.prisma.accessEvent.create({
      data: {
        userId,
        accessGrantId: grant.id,
        doorId: doorId ?? null,
        status: 'DENIED',
        reason,
        createdAt: event.occurredAt,
      },
    });
  }

  private async processDoorAlert(event: any): Promise<void> {
    const payload = event.payload as Record<string, string>;
    this.logger.warn(
      `[Edge] DOOR ALERT ${event.eventType} — device=${event.deviceId} door=${payload.doorId} at ${event.occurredAt}`,
    );
    // Alert surface: logged for operator dashboard. Physical security team
    // reads this from the admin logs endpoint (/api/admin/logs).
  }

  private async processDeviceLifecycle(event: any): Promise<void> {
    await this.prisma.device.updateMany({
      where: { tenantId: event.tenantId, doorId: event.deviceId },
      data: { lastSeenAt: event.occurredAt },
    });
  }

  /**
   * When no valid grant can be found for an offline replay (e.g., grant expired
   * between the offline event and replay time), we use the most recent grant
   * as a fallback to satisfy the FK constraint.
   */
  private async getFallbackGrantId(userId: string): Promise<string> {
    const grant = await this.prisma.accessGrant.findFirst({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });
    if (!grant) throw new Error(`No access grant found for user ${userId}`);
    return grant.id;
  }
}
