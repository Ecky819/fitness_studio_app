/**
 * AnalyticsService — Unit Tests
 *
 * All Prisma queries are mocked. Tests verify that the service
 * correctly transforms raw SQL results (BigInt → Number) and
 * fills missing hours with count=0 in getPeakHours.
 */
import { Test, TestingModule } from '@nestjs/testing';
import { AnalyticsService } from '../src/modules/analytics/analytics.service';
import { PrismaService } from '../src/prisma/prisma.service';

describe('AnalyticsService', () => {
  let service: AnalyticsService;

  const mockPrisma = {
    $queryRaw: jest.fn(),
    user: { count: jest.fn() },
    subscription: { count: jest.fn() },
    payment: { aggregate: jest.fn() },
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AnalyticsService,
        { provide: PrismaService, useValue: mockPrisma },
      ],
    }).compile();

    service = module.get<AnalyticsService>(AnalyticsService);
  });

  // ── getDailyUsage ──────────────────────────────────────────────────────────

  describe('getDailyUsage', () => {
    it('maps raw SQL rows (BigInt) to typed objects', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        { day: new Date('2026-01-01T00:00:00Z'), granted: BigInt(42), denied: BigInt(3) },
        { day: new Date('2026-01-02T00:00:00Z'), granted: BigInt(18), denied: BigInt(1) },
      ]);

      const result = await service.getDailyUsage({});

      expect(result).toHaveLength(2);
      expect(result[0]).toEqual({ date: '2026-01-01', granted: 42, denied: 3 });
      expect(result[1]).toEqual({ date: '2026-01-02', granted: 18, denied: 1 });
    });

    it('returns empty array when no events exist', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([]);
      const result = await service.getDailyUsage({});
      expect(result).toEqual([]);
    });
  });

  // ── getPeakHours ──────────────────────────────────────────────────────────

  describe('getPeakHours', () => {
    it('always returns exactly 24 hours', async () => {
      // Only hours 8 and 18 have data
      mockPrisma.$queryRaw.mockResolvedValue([
        { hour: 8, count: BigInt(55) },
        { hour: 18, count: BigInt(92) },
      ]);

      const result = await service.getPeakHours({});

      expect(result).toHaveLength(24);
      expect(result[0]).toEqual({ hour: 0, count: 0 });
      expect(result[8]).toEqual({ hour: 8, count: 55 });
      expect(result[18]).toEqual({ hour: 18, count: 92 });
      expect(result[23]).toEqual({ hour: 23, count: 0 });
    });

    it('all hours are 0 when no data exists', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([]);
      const result = await service.getPeakHours({});
      expect(result).toHaveLength(24);
      expect(result.every((h) => h.count === 0)).toBe(true);
    });
  });

  // ── getRevenue ────────────────────────────────────────────────────────────

  describe('getRevenue', () => {
    it('maps monthly rows and aggregates totals', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([
        { month: new Date('2026-01-01T00:00:00Z'), total_cents: BigInt(29900), count: BigInt(10) },
        { month: new Date('2026-02-01T00:00:00Z'), total_cents: BigInt(59800), count: BigInt(20) },
      ]);
      mockPrisma.payment.aggregate.mockResolvedValue({
        _sum: { amountCents: 89700 },
        _count: 30,
      });

      const result = await service.getRevenue({});

      expect(result.monthly).toHaveLength(2);
      expect(result.monthly[0]).toEqual({ month: '2026-01', totalCents: 29900, count: 10 });
      expect(result.totalCents).toBe(89700);
      expect(result.totalPayments).toBe(30);
    });

    it('handles null aggregate sum (no payments)', async () => {
      mockPrisma.$queryRaw.mockResolvedValue([]);
      mockPrisma.payment.aggregate.mockResolvedValue({ _sum: { amountCents: null }, _count: 0 });

      const result = await service.getRevenue({});
      expect(result.totalCents).toBe(0);
      expect(result.totalPayments).toBe(0);
    });
  });

  // ── getActiveUsers ────────────────────────────────────────────────────────

  describe('getActiveUsers', () => {
    it('returns KPI snapshot with correct types', async () => {
      mockPrisma.user.count
        .mockResolvedValueOnce(500)   // totalUsers
        .mockResolvedValueOnce(12);   // newUsersThisMonth
      mockPrisma.subscription.count.mockResolvedValue(320);
      mockPrisma.$queryRaw.mockResolvedValue([{ count: BigInt(280) }]);

      const result = await service.getActiveUsers();

      expect(result).toEqual({
        totalUsers: 500,
        activeSubscriptions: 320,
        newUsersThisMonth: 12,
        activeUsersLast30Days: 280,
      });
    });

    it('handles empty active users result gracefully', async () => {
      mockPrisma.user.count.mockResolvedValue(0);
      mockPrisma.subscription.count.mockResolvedValue(0);
      mockPrisma.$queryRaw.mockResolvedValue([]);

      const result = await service.getActiveUsers();
      expect(result.activeUsersLast30Days).toBe(0);
    });
  });
});
