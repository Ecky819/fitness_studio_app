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
  type: 'RAPID_RETRIES' | 'OFF_HOURS_ACCESS' | 'MULTIPLE_DENIALS' | 'GHOST_MEMBER';
  userId: string;
  doorId: string;
  count: number;
  windowMinutes: number;
  detectedAt: string;
}

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);

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

      // Retention Workflow: notify HIGH-risk users, throttled to once per 24h per user
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

  // ── Anomaly Detection ──────────────────────────────────────────────────────

  async detectAnomalies(tenantId: string): Promise<AnomalyResult[]> {
    const anomalies: AnomalyResult[] = [];
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

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
      anomalies.push({ type: 'RAPID_RETRIES', userId: d.userId, doorId: d.doorId ?? 'unknown', count: d._count.id, windowMinutes: 5, detectedAt: new Date().toISOString() });
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
      anomalies.push({ type: 'OFF_HOURS_ACCESS', userId: r.userId, doorId: r.doorId ?? 'unknown', count: Number(r.cnt), windowMinutes: 1440, detectedAt: new Date().toISOString() });
    }

    // Ghost members: active subscription but zero visits in 30 days
    const ghosts = await this.prisma.user.findMany({
      where: {
        tenantId,
        isBlocked: false,
        subscriptions: { some: { status: 'ACTIVE' } },
        accessEvents: { none: { createdAt: { gte: thirtyDaysAgo } } },
      },
      select: { id: true },
      take: 50,
    });
    for (const g of ghosts) {
      anomalies.push({ type: 'GHOST_MEMBER', userId: g.id, doorId: 'n/a', count: 0, windowMinutes: 43200, detectedAt: new Date().toISOString() });
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
