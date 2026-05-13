import { Injectable } from '@nestjs/common';
import { SubscriptionStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AnalyticsDateRangeDto } from './dto/analytics-query.dto';

@Injectable()
export class AnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Daily Usage ────────────────────────────────────────────────────────────
  // Returns GRANTED vs DENIED access events grouped by calendar day.
  // Defaults to the last 30 days when no date range is supplied.

  async getDailyUsage(query: AnalyticsDateRangeDto) {
    const dateFrom = query.dateFrom
      ? new Date(query.dateFrom)
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const dateTo = query.dateTo ? new Date(query.dateTo) : new Date();

    const rows = await this.prisma.$queryRaw<
      { day: Date; granted: bigint; denied: bigint }[]
    >`
      SELECT
        DATE_TRUNC('day', "createdAt") AS day,
        COUNT(*) FILTER (WHERE status::text = 'GRANTED')::bigint AS granted,
        COUNT(*) FILTER (WHERE status::text = 'DENIED')::bigint  AS denied
      FROM "AccessEvent"
      WHERE "createdAt" >= ${dateFrom}
        AND "createdAt" <= ${dateTo}
      GROUP BY DATE_TRUNC('day', "createdAt")
      ORDER BY day ASC
    `;

    return rows.map((r) => ({
      date: r.day.toISOString().slice(0, 10),
      granted: Number(r.granted),
      denied: Number(r.denied),
    }));
  }

  // ── Peak Hours ────────────────────────────────────────────────────────────
  // Returns granted access events grouped by hour-of-day (0-23).
  // All 24 hours are always returned — missing hours get count=0.

  async getPeakHours(query: AnalyticsDateRangeDto) {
    const dateFrom = query.dateFrom
      ? new Date(query.dateFrom)
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const dateTo = query.dateTo ? new Date(query.dateTo) : new Date();

    const rows = await this.prisma.$queryRaw<
      { hour: number; count: bigint }[]
    >`
      SELECT
        EXTRACT(HOUR FROM "createdAt")::int AS hour,
        COUNT(*)::bigint                    AS count
      FROM "AccessEvent"
      WHERE status::text = 'GRANTED'
        AND "createdAt" >= ${dateFrom}
        AND "createdAt" <= ${dateTo}
      GROUP BY EXTRACT(HOUR FROM "createdAt")
      ORDER BY hour ASC
    `;

    const hourMap = new Map(rows.map((r) => [Number(r.hour), Number(r.count)]));

    return Array.from({ length: 24 }, (_, h) => ({
      hour: h,
      count: hourMap.get(h) ?? 0,
    }));
  }

  // ── Revenue ───────────────────────────────────────────────────────────────
  // Returns succeeded payments grouped by month plus a running total.
  // Defaults to the last 12 months when no date range is supplied.

  async getRevenue(query: AnalyticsDateRangeDto) {
    const dateFrom = query.dateFrom
      ? new Date(query.dateFrom)
      : new Date(Date.now() - 365 * 24 * 60 * 60 * 1000);
    const dateTo = query.dateTo ? new Date(query.dateTo) : new Date();

    const [monthly, totals] = await Promise.all([
      this.prisma.$queryRaw<
        { month: Date; total_cents: bigint; count: bigint }[]
      >`
        SELECT
          DATE_TRUNC('month', "createdAt") AS month,
          SUM("amountCents")::bigint       AS total_cents,
          COUNT(*)::bigint                 AS count
        FROM "Payment"
        WHERE status = 'succeeded'
          AND "createdAt" >= ${dateFrom}
          AND "createdAt" <= ${dateTo}
        GROUP BY DATE_TRUNC('month', "createdAt")
        ORDER BY month ASC
      `,
      this.prisma.payment.aggregate({
        where: { status: 'succeeded', createdAt: { gte: dateFrom, lte: dateTo } },
        _sum: { amountCents: true },
        _count: true,
      }),
    ]);

    return {
      monthly: monthly.map((r) => ({
        month: r.month.toISOString().slice(0, 7),
        totalCents: Number(r.total_cents),
        count: Number(r.count),
      })),
      totalCents: totals._sum.amountCents ?? 0,
      totalPayments: totals._count,
    };
  }

  // ── Active Users ──────────────────────────────────────────────────────────
  // KPI snapshot: total users, active subscriptions, new registrations this
  // month, and distinct users who successfully accessed in the last 30 days.

  async getActiveUsers() {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const [totalUsers, activeSubscriptions, newUsersThisMonth, activeUsersRaw] =
      await Promise.all([
        this.prisma.user.count(),
        this.prisma.subscription.count({
          where: { status: SubscriptionStatus.ACTIVE, validUntil: { gt: now } },
        }),
        this.prisma.user.count({ where: { createdAt: { gte: startOfMonth } } }),
        this.prisma.$queryRaw<{ count: bigint }[]>`
          SELECT COUNT(DISTINCT "userId")::bigint AS count
          FROM "AccessEvent"
          WHERE status::text = 'GRANTED'
            AND "createdAt" >= ${thirtyDaysAgo}
        `,
      ]);

    return {
      totalUsers,
      activeSubscriptions,
      newUsersThisMonth,
      activeUsersLast30Days: Number(activeUsersRaw[0]?.count ?? 0),
    };
  }
}
