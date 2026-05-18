import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Prisma } from '@prisma/client';
import Redis from 'ioredis';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

export type RiskLevel = 'LOW' | 'MEDIUM' | 'HIGH';

export interface ChurnFactor {
  factor: string;
  weight: number;
  detail: string;
}

export interface ChurnRiskResult {
  userId: string;
  email: string;
  churnScore: number;
  riskLevel: RiskLevel;
  factors: ChurnFactor[];
  recommendation: string;
  computedAt: string;
}

export interface AnomalyResult {
  type: 'RAPID_RETRIES' | 'OFF_HOURS_ACCESS' | 'MULTIPLE_DENIALS' | 'GHOST_MEMBER' | 'TAILGATING';
  userId: string;
  doorId: string;
  count: number;
  windowMinutes: number;
  detectedAt: string;
  details?: Record<string, unknown>;
}

/**
 * Represents a single tailgating incident with detection method metadata.
 *
 * PROXIMITY: Two different users received GRANTED status at the same door within
 * PROXIMITY_WINDOW_SECONDS — the second person likely followed through an open door.
 *
 * DENIAL_THEN_ENTRY: A user was DENIED, then a different user was GRANTED at the
 * same door within DENIAL_WINDOW_SECONDS, and this pattern repeated ≥2 times —
 * strong indicator of deliberate tailgating attempts.
 */
export interface TailgatingIncident {
  suspectedUserId: string;
  doorId: string;
  incidentCount: number;
  method: 'PROXIMITY' | 'DENIAL_THEN_ENTRY';
  windowSeconds: number;
  firstDetectedAt: string;
}

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);

  // Doors re-lock within this window; two grants in this time = tailgating risk
  private readonly PROXIMITY_WINDOW_SECONDS = 15;
  // Denial immediately before/after a grant at same door = attempted piggyback
  private readonly DENIAL_WINDOW_SECONDS = 60;
  // Min occurrences to surface a DENIAL_THEN_ENTRY incident (noise filter)
  private readonly DENIAL_MIN_OCCURRENCES = 2;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    @Inject('REDIS_CLIENT') private readonly redis: Redis,
  ) {}

  // ── Churn Risk ──────────────────────────────────────────────────────────────

  async getChurnRiskForTenant(tenantId: string, limit = 50): Promise<ChurnRiskResult[]> {
    const cached = await this.prisma.aiInsight.findMany({
      where: { tenantId, expiresAt: { gt: new Date() } },
      orderBy: { churnScore: 'desc' },
      take: limit,
      include: { user: { select: { email: true } } },
    });

    if (cached.length > 0) {
      return cached.map((c) => ({
        userId: c.userId,
        email: c.user.email,
        churnScore: c.churnScore,
        riskLevel: c.riskLevel as RiskLevel,
        factors: c.factors as unknown as ChurnFactor[],
        recommendation: c.recommendation ?? '',
        computedAt: c.computedAt.toISOString(),
      }));
    }

    return this.computeAndCacheChurnRisk(tenantId, limit);
  }

  async computeAndCacheChurnRisk(
    tenantId: string,
    limit = 200,
    triggerRetentionAlerts = false,
  ): Promise<ChurnRiskResult[]> {
    const now = new Date();
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const sixtyDaysAgo = new Date(Date.now() - 60 * 24 * 60 * 60 * 1000);
    const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);

    const users = await this.prisma.user.findMany({
      where: { tenantId, isBlocked: false },
      take: limit,
      select: {
        id: true,
        email: true,
        subscriptions: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { status: true, validUntil: true },
        },
      },
    });

    const results: ChurnRiskResult[] = [];

    for (const user of users) {
      const sub = user.subscriptions[0] ?? null;
      const factors: ChurnFactor[] = [];
      let score = 0;

      // Factor A: Days since last access (max 40 pts)
      const lastAccess = await this.prisma.accessEvent.findFirst({
        where: { userId: user.id, status: 'GRANTED' },
        orderBy: { createdAt: 'desc' },
        select: { createdAt: true },
      });

      if (!lastAccess) {
        score += 40;
        factors.push({ factor: 'NEVER_ACCESSED', weight: 40, detail: 'No access event recorded' });
      } else {
        const daysSince = Math.floor((now.getTime() - lastAccess.createdAt.getTime()) / 86_400_000);
        if (daysSince > 30) {
          score += 40;
          factors.push({ factor: 'LONG_ABSENCE', weight: 40, detail: `${daysSince} days since last visit` });
        } else if (daysSince > 14) {
          score += 25;
          factors.push({ factor: 'MODERATE_ABSENCE', weight: 25, detail: `${daysSince} days since last visit` });
        } else if (daysSince > 7) {
          score += 10;
          factors.push({ factor: 'SHORT_ABSENCE', weight: 10, detail: `${daysSince} days since last visit` });
        }
      }

      // Factor B: Subscription status (max 30 pts)
      if (!sub) {
        score += 30;
        factors.push({ factor: 'NO_SUBSCRIPTION', weight: 30, detail: 'No subscription found' });
      } else if (sub.status === 'PAST_DUE') {
        score += 30;
        factors.push({ factor: 'PAST_DUE', weight: 30, detail: 'Payment overdue' });
      } else if (sub.status === 'CANCELED') {
        score = 100;
        factors.push({ factor: 'CANCELED', weight: 100, detail: 'Subscription cancelled' });
      } else if (sub.validUntil < new Date(Date.now() + 7 * 86_400_000)) {
        score += 15;
        factors.push({ factor: 'EXPIRING_SOON', weight: 15, detail: `Expires ${sub.validUntil.toDateString()}` });
      }

      // Factor C: Payment failures 90d (max 20 pts)
      const failedPayments = await this.prisma.payment.count({
        where: { userId: user.id, status: { in: ['failed', 'payment_failed'] }, createdAt: { gte: ninetyDaysAgo } },
      });
      if (failedPayments > 2) {
        score += 20;
        factors.push({ factor: 'MULTIPLE_PAYMENT_FAILURES', weight: 20, detail: `${failedPayments} failed payments in 90 days` });
      } else if (failedPayments > 0) {
        score += 10;
        factors.push({ factor: 'PAYMENT_FAILURE', weight: 10, detail: `${failedPayments} failed payment(s) in 90 days` });
      }

      // Factor D: Access frequency trend (max 10 pts)
      const [recent, prior] = await Promise.all([
        this.prisma.accessEvent.count({ where: { userId: user.id, status: 'GRANTED', createdAt: { gte: thirtyDaysAgo } } }),
        this.prisma.accessEvent.count({ where: { userId: user.id, status: 'GRANTED', createdAt: { gte: sixtyDaysAgo, lt: thirtyDaysAgo } } }),
      ]);
      if (prior > 0 && (recent - prior) / prior < -0.5) {
        score += 10;
        factors.push({ factor: 'DECLINING_FREQUENCY', weight: 10, detail: `Visit frequency down ${Math.round(((prior - recent) / prior) * 100)}%` });
      }

      score = Math.min(score, 100);
      const riskLevel: RiskLevel = score >= 60 ? 'HIGH' : score >= 30 ? 'MEDIUM' : 'LOW';
      const recommendation = this.buildRecommendation(riskLevel, factors);
      const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);
      const factorsJson = factors as unknown as Prisma.InputJsonValue;

      await this.prisma.aiInsight.upsert({
        where: { tenantId_userId: { tenantId, userId: user.id } },
        create: { tenantId, userId: user.id, churnScore: score, riskLevel, factors: factorsJson, recommendation, expiresAt },
        update: { churnScore: score, riskLevel, factors: factorsJson, recommendation, computedAt: now, expiresAt },
      });

      results.push({ userId: user.id, email: user.email, churnScore: score, riskLevel, factors, recommendation, computedAt: now.toISOString() });

      if (triggerRetentionAlerts && riskLevel === 'HIGH') {
        const throttleKey = `retention:alert:${tenantId}:${user.id}`;
        if (!(await this.redis.get(throttleKey))) {
          await this.notificationsService.sendRetentionAlertNotification(user.id, score, recommendation);
          await this.redis.setex(throttleKey, 86_400, '1');
        }
      }
    }

    return results.sort((a, b) => b.churnScore - a.churnScore);
  }

  // ── Tailgating Detection ────────────────────────────────────────────────────

  /**
   * Detects tailgating via two complementary strategies:
   *
   * Strategy 1 – PROXIMITY:
   *   Two different users received GRANTED access at the same door within
   *   PROXIMITY_WINDOW_SECONDS (15 s). Only one person physically swiped;
   *   the other likely slipped through before the door re-locked.
   *
   * Strategy 2 – DENIAL_THEN_ENTRY:
   *   A user was DENIED at a door, then a different user was GRANTED at the
   *   same door within DENIAL_WINDOW_SECONDS. This pattern repeating ≥2 times
   *   strongly suggests deliberate tailgating (waiting for someone to open).
   */
  async detectTailgating(tenantId: string): Promise<TailgatingIncident[]> {
    const [proximityRows, denialRows] = await Promise.all([
      this.prisma.$queryRaw<
        { suspectedUserId: string; doorId: string; cnt: bigint; firstIncidentAt: Date }[]
      >`
        SELECT
          ae2."userId"          AS "suspectedUserId",
          ae1."doorId",
          COUNT(*)::bigint      AS cnt,
          MIN(ae2."createdAt")  AS "firstIncidentAt"
        FROM "AccessEvent" ae1
        JOIN "AccessEvent" ae2
          ON ae1."doorId" = ae2."doorId"
          AND ae1.id < ae2.id
          AND ae1."userId" != ae2."userId"
          AND ae2."createdAt" > ae1."createdAt"
          AND ae2."createdAt" <= ae1."createdAt" + INTERVAL '15 seconds'
        JOIN "User" u ON u.id = ae1."userId" AND u."tenantId" = ${tenantId}
        WHERE ae1.status::text = 'GRANTED'
          AND ae2.status::text = 'GRANTED'
          AND ae1."doorId" IS NOT NULL
          AND ae1."createdAt" >= NOW() - INTERVAL '24 hours'
        GROUP BY ae2."userId", ae1."doorId"
        ORDER BY cnt DESC
        LIMIT 50
      `,

      this.prisma.$queryRaw<
        { suspectedUserId: string; doorId: string; cnt: bigint; lastAttemptAt: Date }[]
      >`
        SELECT
          denied_ae."userId"          AS "suspectedUserId",
          denied_ae."doorId",
          COUNT(*)::bigint            AS cnt,
          MAX(denied_ae."createdAt")  AS "lastAttemptAt"
        FROM "AccessEvent" denied_ae
        JOIN "AccessEvent" granted_ae
          ON granted_ae."doorId" = denied_ae."doorId"
          AND granted_ae.status::text = 'GRANTED'
          AND denied_ae.status::text = 'DENIED'
          AND denied_ae."userId" != granted_ae."userId"
          AND denied_ae."createdAt" BETWEEN
                granted_ae."createdAt" - INTERVAL '60 seconds'
            AND granted_ae."createdAt" + INTERVAL '30 seconds'
        JOIN "User" u ON u.id = denied_ae."userId" AND u."tenantId" = ${tenantId}
        WHERE denied_ae."doorId" IS NOT NULL
          AND denied_ae."createdAt" >= NOW() - INTERVAL '24 hours'
        GROUP BY denied_ae."userId", denied_ae."doorId"
        HAVING COUNT(*) >= 2
        ORDER BY cnt DESC
        LIMIT 50
      `,
    ]);

    const incidents: TailgatingIncident[] = [
      ...proximityRows.map((r) => ({
        suspectedUserId: r.suspectedUserId,
        doorId: r.doorId,
        incidentCount: Number(r.cnt),
        method: 'PROXIMITY' as const,
        windowSeconds: this.PROXIMITY_WINDOW_SECONDS,
        firstDetectedAt: r.firstIncidentAt.toISOString(),
      })),
      ...denialRows.map((r) => ({
        suspectedUserId: r.suspectedUserId,
        doorId: r.doorId,
        incidentCount: Number(r.cnt),
        method: 'DENIAL_THEN_ENTRY' as const,
        windowSeconds: this.DENIAL_WINDOW_SECONDS,
        firstDetectedAt: r.lastAttemptAt.toISOString(),
      })),
    ];

    return incidents.sort((a, b) => b.incidentCount - a.incidentCount);
  }

  // ── Ghost Detection ─────────────────────────────────────────────────────────

  /**
   * Finds members with an active subscription but no GRANTED access events
   * in the last 30 days. Returns enriched results including days since last
   * visit and whether the member has never accessed the facility at all.
   */
  async detectGhostMembers(tenantId: string, limit = 50): Promise<AnomalyResult[]> {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const now = new Date();

    const rows = await this.prisma.$queryRaw<
      { id: string; lastAccessAt: Date | null }[]
    >`
      SELECT u.id, MAX(ae."createdAt") AS "lastAccessAt"
      FROM "User" u
      INNER JOIN "Subscription" s
        ON s."userId" = u.id AND s.status::text = 'ACTIVE'
      LEFT JOIN "AccessEvent" ae
        ON ae."userId" = u.id AND ae.status::text = 'GRANTED'
      WHERE u."tenantId" = ${tenantId}
        AND u."isBlocked" = false
      GROUP BY u.id
      HAVING MAX(ae."createdAt") IS NULL
          OR MAX(ae."createdAt") < ${thirtyDaysAgo}
      LIMIT ${limit}
    `;

    return rows.map((g) => {
      const neverAccessed = g.lastAccessAt === null;
      const daysSinceLastVisit = neverAccessed
        ? null
        : Math.floor((now.getTime() - g.lastAccessAt!.getTime()) / 86_400_000);

      return {
        type: 'GHOST_MEMBER' as const,
        userId: g.id,
        doorId: 'n/a',
        count: 0,
        windowMinutes: 43_200,
        detectedAt: now.toISOString(),
        details: {
          neverAccessed,
          daysSinceLastVisit,
        },
      };
    });
  }

  // ── Anomaly Detection (aggregated) ─────────────────────────────────────────

  async detectAnomalies(tenantId: string): Promise<AnomalyResult[]> {
    const anomalies: AnomalyResult[] = [];
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    const now = new Date();

    const userIds = await this.prisma.user
      .findMany({ where: { tenantId }, select: { id: true } })
      .then((rows) => rows.map((r) => r.id));

    // Rapid denied retries (>3 in 5 min)
    const rapidDenials = await this.prisma.accessEvent.groupBy({
      by: ['userId', 'doorId'],
      where: { userId: { in: userIds }, status: 'DENIED', createdAt: { gte: fiveMinutesAgo } },
      _count: { id: true },
      having: { id: { _count: { gt: 3 } } },
    });
    for (const d of rapidDenials) {
      anomalies.push({
        type: 'RAPID_RETRIES',
        userId: d.userId,
        doorId: d.doorId ?? 'unknown',
        count: d._count.id,
        windowMinutes: 5,
        detectedAt: now.toISOString(),
      });
    }

    // Off-hours access (00:00–04:59)
    const offHours = await this.prisma.$queryRaw<{ userId: string; doorId: string; cnt: bigint }[]>`
      SELECT ae."userId", ae."doorId", COUNT(*)::bigint AS cnt
      FROM "AccessEvent" ae
      INNER JOIN "User" u ON u.id = ae."userId"
      WHERE u."tenantId" = ${tenantId}
        AND ae.status::text = 'GRANTED'
        AND EXTRACT(HOUR FROM ae."createdAt") BETWEEN 0 AND 4
        AND ae."createdAt" >= NOW() - INTERVAL '24 hours'
      GROUP BY ae."userId", ae."doorId"
    `;
    for (const r of offHours) {
      anomalies.push({
        type: 'OFF_HOURS_ACCESS',
        userId: r.userId,
        doorId: r.doorId ?? 'unknown',
        count: Number(r.cnt),
        windowMinutes: 1440,
        detectedAt: now.toISOString(),
      });
    }

    // Ghost members (active subscription, no visits in 30 days)
    const ghosts = await this.detectGhostMembers(tenantId);
    anomalies.push(...ghosts);

    // Tailgating
    const tailgating = await this.detectTailgating(tenantId);
    for (const t of tailgating) {
      anomalies.push({
        type: 'TAILGATING',
        userId: t.suspectedUserId,
        doorId: t.doorId,
        count: t.incidentCount,
        windowMinutes: Math.ceil(t.windowSeconds / 60),
        detectedAt: now.toISOString(),
        details: { method: t.method, windowSeconds: t.windowSeconds },
      });
    }

    return anomalies;
  }

  // ── Background Job ─────────────────────────────────────────────────────────

  @Cron(CronExpression.EVERY_6_HOURS)
  async refreshHighRiskScores() {
    this.logger.log('Refreshing churn risk scores + triggering retention workflows');
    const tenants = await this.prisma.tenant.findMany({ where: { status: 'ACTIVE' }, select: { id: true } });
    for (const { id } of tenants) {
      await this.computeAndCacheChurnRisk(id, 200, true);
    }
  }

  // ── Private ────────────────────────────────────────────────────────────────

  private buildRecommendation(level: RiskLevel, factors: ChurnFactor[]): string {
    if (level === 'HIGH') {
      const hasPayment = factors.some((f) => f.factor.includes('PAYMENT') || f.factor === 'PAST_DUE');
      return hasPayment
        ? 'Send payment reminder. Offer a grace period extension.'
        : 'Reach out personally. Offer a free PT session or class to re-engage.';
    }
    if (level === 'MEDIUM') return 'Send a "We miss you" email with a personalised offer.';
    return 'Member is active. Monitor for changes.';
  }
}
