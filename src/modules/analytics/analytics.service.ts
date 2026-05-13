import { Injectable } from '@nestjs/common';
import { SubscriptionStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AnalyticsDateRangeDto } from './dto/analytics-query.dto';

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Daily Usage ─────────────────────────────────────────────────────────────

  async getDailyUsage(tenantId: string, query: AnalyticsDateRangeDto) {
    const dateFrom = query.dateFrom
      ? new Date(query.dateFrom)
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const dateTo = query.dateTo ? new Date(query.dateTo) : new Date();

    const rows = await this.prisma.$queryRaw<
      { day: Date; granted: bigint; denied: bigint }[]
    >`
      SELECT
        DATE_TRUNC('day', ae."createdAt") AS day,
        COUNT(*) FILTER (WHERE ae.status::text = 'GRANTED')::bigint AS granted,
        COUNT(*) FILTER (WHERE ae.status::text = 'DENIED')::bigint  AS denied
      FROM "AccessEvent" ae
      INNER JOIN "User" u ON u.id = ae."userId"
      WHERE u."tenantId" = ${tenantId}
        AND ae."createdAt" >= ${dateFrom}
        AND ae."createdAt" <= ${dateTo}
      GROUP BY DATE_TRUNC('day', ae."createdAt")
      ORDER BY day ASC
    `;

    return rows.map((r) => ({
      date: r.day.toISOString().slice(0, 10),
      granted: Number(r.granted),
      denied: Number(r.denied),
    }));
  }

  // ── Peak Hours ───────────────────────────────────────────────────────────────

  async getPeakHours(tenantId: string, query: AnalyticsDateRangeDto) {
    const dateFrom = query.dateFrom
      ? new Date(query.dateFrom)
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const dateTo = query.dateTo ? new Date(query.dateTo) : new Date();

    const rows = await this.prisma.$queryRaw<
      { hour: number; count: bigint }[]
    >`
      SELECT
        EXTRACT(HOUR FROM ae."createdAt")::int AS hour,
        COUNT(*)::bigint                       AS count
      FROM "AccessEvent" ae
      INNER JOIN "User" u ON u.id = ae."userId"
      WHERE u."tenantId" = ${tenantId}
        AND ae.status::text = 'GRANTED'
        AND ae."createdAt" >= ${dateFrom}
        AND ae."createdAt" <= ${dateTo}
      GROUP BY EXTRACT(HOUR FROM ae."createdAt")
      ORDER BY hour ASC
    `;

    const hourMap = new Map(rows.map((r) => [Number(r.hour), Number(r.count)]));
    return Array.from({ length: 24 }, (_, h) => ({
      hour: h,
      count: hourMap.get(h) ?? 0,
    }));
  }

  // ── Revenue ──────────────────────────────────────────────────────────────────

  async getRevenue(tenantId: string, query: AnalyticsDateRangeDto) {
    const dateFrom = query.dateFrom
      ? new Date(query.dateFrom)
      : new Date(Date.now() - 365 * 24 * 60 * 60 * 1000);
    const dateTo = query.dateTo ? new Date(query.dateTo) : new Date();

    const [monthly, totals] = await Promise.all([
      this.prisma.$queryRaw<
        { month: Date; total_cents: bigint; count: bigint }[]
      >`
        SELECT
          DATE_TRUNC('month', p."createdAt") AS month,
          SUM(p."amountCents")::bigint        AS total_cents,
          COUNT(*)::bigint                    AS count
        FROM "Payment" p
        INNER JOIN "User" u ON u.id = p."userId"
        WHERE u."tenantId" = ${tenantId}
          AND p.status = 'succeeded'
          AND p."createdAt" >= ${dateFrom}
          AND p."createdAt" <= ${dateTo}
        GROUP BY DATE_TRUNC('month', p."createdAt")
        ORDER BY month ASC
      `,
      this.prisma.$queryRaw<{ total: bigint; cnt: bigint }[]>`
        SELECT
          COALESCE(SUM(p."amountCents"), 0)::bigint AS total,
          COUNT(*)::bigint                          AS cnt
        FROM "Payment" p
        INNER JOIN "User" u ON u.id = p."userId"
        WHERE u."tenantId" = ${tenantId}
          AND p.status = 'succeeded'
          AND p."createdAt" >= ${dateFrom}
          AND p."createdAt" <= ${dateTo}
      `,
    ]);

    return {
      monthly: monthly.map((r) => ({
        month: r.month.toISOString().slice(0, 7),
        totalCents: Number(r.total_cents),
        count: Number(r.count),
      })),
      totalCents: Number(totals[0]?.total ?? 0),
      totalPayments: Number(totals[0]?.cnt ?? 0),
    };
  }

  // ── Active Users ──────────────────────────────────────────────────────────────

  async getActiveUsers(tenantId: string) {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const [totalUsers, newUsersThisMonth, activeSubRaw, activeUsersRaw] =
      await Promise.all([
        this.prisma.user.count({ where: { tenantId } }),
        this.prisma.user.count({ where: { tenantId, createdAt: { gte: startOfMonth } } }),
        // Active subscriptions scoped via user
        this.prisma.$queryRaw<{ count: bigint }[]>`
          SELECT COUNT(*)::bigint AS count
          FROM "Subscription" s
          INNER JOIN "User" u ON u.id = s."userId"
          WHERE u."tenantId" = ${tenantId}
            AND s.status = 'ACTIVE'
            AND s."validUntil" > ${now}
        `,
        this.prisma.$queryRaw<{ count: bigint }[]>`
          SELECT COUNT(DISTINCT ae."userId")::bigint AS count
          FROM "AccessEvent" ae
          INNER JOIN "User" u ON u.id = ae."userId"
          WHERE u."tenantId" = ${tenantId}
            AND ae.status::text = 'GRANTED'
            AND ae."createdAt" >= ${thirtyDaysAgo}
        `,
      ]);

    return {
      totalUsers,
      activeSubscriptions: Number(activeSubRaw[0]?.count ?? 0),
      newUsersThisMonth,
      activeUsersLast30Days: Number(activeUsersRaw[0]?.count ?? 0),
    };
  }
}
