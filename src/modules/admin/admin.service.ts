import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminLogsQueryDto, AdminUsersQueryDto } from './dto/admin-query.dto';
import { AccessEventStatus, SubscriptionStatus } from '@prisma/client';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Stats ──────────────────────────────────────────────────────────────────

  async getStats() {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const [
      totalUsers,
      activeSubscriptions,
      todayEvents,
      totalDevices,
      onlineDevices,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.subscription.count({
        where: { status: SubscriptionStatus.ACTIVE, validUntil: { gt: now } },
      }),
      this.prisma.accessEvent.findMany({
        where: { createdAt: { gte: startOfDay } },
        select: { status: true },
      }),
      this.prisma.device.count(),
      this.prisma.device.count({
        where: {
          isOnline: true,
          lastSeenAt: { gte: new Date(Date.now() - 5 * 60_000) },
        },
      }),
    ]);

    const granted = todayEvents.filter((e) => e.status === AccessEventStatus.GRANTED).length;
    const denied = todayEvents.filter((e) => e.status === AccessEventStatus.DENIED).length;

    return {
      totalUsers,
      activeSubscriptions,
      todayGranted: granted,
      todayDenied: denied,
      totalDevices,
      onlineDevices,
    };
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  async getUsers(query: AdminUsersQueryDto) {
    const users = await this.prisma.user.findMany({
      where: query.search
        ? { email: { contains: query.search, mode: 'insensitive' } }
        : undefined,
      select: {
        id: true,
        email: true,
        role: true,
        isBlocked: true,
        createdAt: true,
        subscriptions: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: {
            status: true,
            validUntil: true,
            plan: { select: { name: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return users.map((u) => {
      const sub = u.subscriptions[0] ?? null;
      return {
        id: u.id,
        email: u.email,
        role: u.role,
        isBlocked: u.isBlocked,
        createdAt: u.createdAt,
        membership: sub
          ? {
              status: sub.status,
              validUntil: sub.validUntil,
              plan: sub.plan.name,
            }
          : null,
      };
    });
  }

  async toggleBlock(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { isBlocked: !user.isBlocked },
      select: { id: true, email: true, isBlocked: true },
    });

    return updated;
  }

  // ── Devices ────────────────────────────────────────────────────────────────

  async getDevices() {
    const cutoff = new Date(Date.now() - 5 * 60_000);
    const devices = await this.prisma.device.findMany({
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

  async getLogs(query: AdminLogsQueryDto) {
    const where: Record<string, unknown> = {};

    if (query.userId) where.userId = query.userId;

    if (query.dateFrom || query.dateTo) {
      where.createdAt = {
        ...(query.dateFrom ? { gte: new Date(query.dateFrom) } : {}),
        ...(query.dateTo
          ? {
              lte: new Date(
                new Date(query.dateTo).setHours(23, 59, 59, 999),
              ),
            }
          : {}),
      };
    }

    // doorId lives on the AccessGrant, not AccessEvent — filter via relation
    const whereClause = query.doorId
      ? {
          ...where,
          accessGrant: { user: { accessGrants: { some: {} } } },
        }
      : where;

    const [total, events] = await Promise.all([
      this.prisma.accessEvent.count({ where: whereClause }),
      this.prisma.accessEvent.findMany({
        where: whereClause,
        orderBy: { createdAt: 'desc' },
        skip: query.offset ?? 0,
        take: query.limit ?? 50,
        select: {
          id: true,
          status: true,
          reason: true,
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
        status: e.status,
        reason: e.reason,
        timestamp: e.createdAt,
      })),
    };
  }
}
