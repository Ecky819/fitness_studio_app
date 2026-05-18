import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AdminLogsQueryDto, AdminUsersQueryDto, FirmwareUpdateDto, ProvisionDeviceDto } from './dto/admin-query.dto';
import { AccessEventStatus, Prisma, SubscriptionStatus } from '@prisma/client';
import { MqttService } from '../mqtt/mqtt.service';
import { randomUUID } from 'crypto';

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly mqtt: MqttService,
  ) {}

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

  // ── OTA Firmware ───────────────────────────────────────────────────────────

  async pushFirmwareUpdate(tenantId: string, deviceId: string, dto: FirmwareUpdateDto) {
    const device = await this.prisma.device.findFirst({ where: { id: deviceId, tenantId } });
    if (!device) throw new NotFoundException('Device not found');

    this.mqtt.publish(`gym/${tenantId}/door/${device.doorId}/ota`, {
      action: 'update',
      firmwareUrl: dto.firmwareUrl,
      version: dto.version,
      ...(dto.checksum ? { checksum: dto.checksum } : {}),
      ts: new Date().toISOString(),
    });

    return { deviceId, doorId: device.doorId, targetVersion: dto.version, status: 'pending' };
  }

  // ── Device Provisioning ─────────────────────────────────────────────────────

  async provisionDevice(tenantId: string, dto: ProvisionDeviceDto) {
    const existing = await this.prisma.device.findUnique({ where: { doorId: dto.doorId } });
    if (existing) throw new BadRequestException(`doorId "${dto.doorId}" is already registered`);

    const provisioningToken = randomUUID();

    const device = await this.prisma.device.create({
      data: {
        tenantId,
        name: dto.name,
        doorId: dto.doorId,
        location: dto.location,
        provisioningToken,
        ...(dto.streamUrl ? { streamUrl: dto.streamUrl, type: 'CAMERA' } : {}),
      },
      select: { id: true, doorId: true, name: true, location: true, type: true, createdAt: true },
    });

    return { ...device, provisioningToken };
  }

  // ── Logs ───────────────────────────────────────────────────────────────────
  //
  // Queries AccessAttempt (the full audit trail) instead of AccessEvent so that
  // denied attempts without a valid grant — replay attacks, expired memberships,
  // unknown tokens — are visible to the operator. AccessEvent only exists when a
  // grant FK was available; AccessAttempt captures every single attempt.

  async getLogs(tenantId: string, query: AdminLogsQueryDto) {
    // Resolve users for this tenant, optionally filtered by email search.
    const users = await this.prisma.user.findMany({
      where: {
        tenantId,
        ...(query.userSearch
          ? { email: { contains: query.userSearch, mode: 'insensitive' } }
          : {}),
        ...(query.userId ? { id: query.userId } : {}),
      },
      select: { id: true, email: true },
    });

    // If a search term was provided but no users matched, return early.
    if ((query.userSearch || query.userId) && users.length === 0) {
      return { total: 0, limit: query.limit ?? 50, offset: query.offset ?? 0, data: [] };
    }

    const userMap = new Map(users.map((u) => [u.id, u.email]));
    const userIds = [...userMap.keys()];

    const where: Prisma.AccessAttemptWhereInput = {
      userId: { in: userIds },
      ...(query.doorId ? { doorId: query.doorId } : {}),
      ...(query.status !== undefined ? { success: query.status === 'GRANTED' } : {}),
      ...((query.dateFrom || query.dateTo)
        ? {
            createdAt: {
              ...(query.dateFrom ? { gte: new Date(query.dateFrom) } : {}),
              ...(query.dateTo
                ? { lte: new Date(new Date(query.dateTo).setHours(23, 59, 59, 999)) }
                : {}),
            },
          }
        : {}),
    };

    const [total, attempts] = await Promise.all([
      this.prisma.accessAttempt.count({ where }),
      this.prisma.accessAttempt.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: query.offset ?? 0,
        take: query.limit ?? 50,
        select: {
          id: true,
          userId: true,
          doorId: true,
          grantId: true,
          success: true,
          reason: true,
          createdAt: true,
        },
      }),
    ]);

    return {
      total,
      limit: query.limit ?? 50,
      offset: query.offset ?? 0,
      data: attempts.map((a) => ({
        id: a.id,
        userId: a.userId,
        userEmail: userMap.get(a.userId) ?? a.userId,
        grantId: a.grantId,
        doorId: a.doorId,
        status: a.success ? 'GRANTED' : 'DENIED',
        reason: a.reason,
        timestamp: a.createdAt,
      })),
    };
  }
}
