import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminLogsQueryDto, AdminUsersQueryDto } from './dto/admin-query.dto';
import { AccessEventStatus, SubscriptionStatus } from '@prisma/client';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Stats ──────────────────────────────────────────────────────────────────

  async getStats(tenantId: string) {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const tenantUserIds = await this.prisma.user
      .findMany({ where: { tenantId }, select: { id: true } })
      .then((rows) => rows.map((r) => r.id));

    const [
      totalUsers,
      activeSubscriptions,
      todayEvents,
      totalDevices,
      onlineDevices,
    ] = await Promise.all([
      this.prisma.user.count({ where: { tenantId } }),
      this.prisma.subscription.count({
        where: {
          userId: { in: tenantUserIds },
          status: SubscriptionStatus.ACTIVE,
          validUntil: { gt: now },
        },
      }),
      this.prisma.accessEvent.findMany({
        where: { userId: { in: tenantUserIds }, createdAt: { gte: startOfDay } },
        select: { status: true },
      }),
      this.prisma.device.count({ where: { tenantId } }),
      this.prisma.device.count({
        where: {
          tenantId,
          isOnline: true,
          lastSeenAt: { gte: new Date(Date.now() - 5 * 60_000) },
        },
      }),
    ]);

    const granted = todayEvents.filter((e) => e.status === AccessEventStatus.GRANTED).length;
    const denied = todayEvents.filter((e) => e.status === AccessEventStatus.DENIED).length;

    return { totalUsers, activeSubscriptions, todayGranted: granted, todayDenied: denied, totalDevices, onlineDevices };
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  async getUsers(tenantId: string, query: AdminUsersQueryDto) {
    const users = await this.prisma.user.findMany({
      where: {
        tenantId,
        ...(query.search
          ? { email: { contains: query.search, mode: 'insensitive' } }
          : {}),
      },
      select: {
        id: true,
        email: true,
        role: true,
        isBlocked: true,
        createdAt: true,
        subscriptions: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { status: true, validUntil: true, plan: { select: { name: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: query.limit ?? 50,
      skip: query.offset ?? 0,
    });

    return {
      data: users.map((u) => {
        const sub = u.subscriptions[0] ?? null;
        return {
          id: u.id,
          email: u.email,
          role: u.role,
          isBlocked: u.isBlocked,
          createdAt: u.createdAt,
          membership: sub
            ? { status: sub.status, validUntil: sub.validUntil, plan: sub.plan.name }
            : null,
        };
      }),
    };
  }

  async toggleBlock(userId: string, tenantId: string) {
    const user = await this.prisma.user.findFirst({ where: { id: userId, tenantId } });
    if (!user) throw new NotFoundException('User not found');

    return this.prisma.user.update({
      where: { id: userId },
      data: { isBlocked: !user.isBlocked },
      select: { id: true, email: true, isBlocked: true },
    });
  }

  // ── Devices ────────────────────────────────────────────────────────────────

  async getDevices(tenantId: string) {
    const cutoff = new Date(Date.now() - 5 * 60_000);
    const devices = await this.prisma.device.findMany({
      where: { tenantId },
      orderBy: { lastSeenAt: 'desc' },
    });

    return devices.map((d) => ({
      id: d.id,
      name: d.name,
      doorId: d.doorId,
      location: d.location,
      firmwareVersion: d.firmwareVersion,
      isOnline: d.isOnline && d.lastSeenAt != null && d.lastSeenAt > cutoff,
      lastSeenAt: d.lastSeenAt,
      createdAt: d.createdAt,
    }));
  }

  // ── Logs ───────────────────────────────────────────────────────────────────

  async getLogs(tenantId: string, query: AdminLogsQueryDto) {
    // Scope to users of this tenant
    const tenantUserIds = await this.prisma.user
      .findMany({ where: { tenantId }, select: { id: true } })
      .then((rows) => rows.map((r) => r.id));

    const where: Record<string, unknown> = { userId: { in: tenantUserIds } };

    if (query.userId) where.userId = query.userId;
    if (query.doorId) where.doorId = query.doorId;

    if (query.dateFrom || query.dateTo) {
      where.createdAt = {
        ...(query.dateFrom ? { gte: new Date(query.dateFrom) } : {}),
        ...(query.dateTo
          ? { lte: new Date(new Date(query.dateTo).setHours(23, 59, 59, 999)) }
          : {}),
      };
    }

    const [total, events] = await Promise.all([
      this.prisma.accessEvent.count({ where }),
      this.prisma.accessEvent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: query.offset ?? 0,
        take: query.limit ?? 50,
        select: {
          id: true,
          status: true,
          reason: true,
          doorId: true,
          createdAt: true,
          user: { select: { id: true, email: true } },
          accessGrant: { select: { id: true } },
        },
      }),
    ]);

    return {
      total,
      limit: query.limit ?? 50,
      offset: query.offset ?? 0,
      data: events.map((e) => ({
        id: e.id,
        userId: e.user.id,
        userEmail: e.user.email,
        grantId: e.accessGrant.id,
        doorId: e.doorId,
        status: e.status,
        reason: e.reason,
        timestamp: e.createdAt,
      })),
    };
  }
}
