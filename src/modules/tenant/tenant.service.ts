import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateTenantDto } from './dto/create-tenant.dto';
import { UpdateTenantConfigDto } from './dto/update-tenant-config.dto';

// Feature flags available per SaaS plan
export const PLAN_FEATURES: Record<string, string[]> = {
  STARTER: ['BASIC_ANALYTICS', 'SINGLE_DOOR', 'EMAIL_NOTIFICATIONS'],
  PRO: [
    'BASIC_ANALYTICS',
    'ADVANCED_ANALYTICS',
    'MULTI_DOOR',
    'EMAIL_NOTIFICATIONS',
    'CUSTOM_BRANDING',
    'CSV_EXPORT',
  ],
  ENTERPRISE: [
    'BASIC_ANALYTICS',
    'ADVANCED_ANALYTICS',
    'MULTI_DOOR',
    'EMAIL_NOTIFICATIONS',
    'CUSTOM_BRANDING',
    'CSV_EXPORT',
    'API_ACCESS',
    'STRIPE_CONNECT',
    'WHITE_LABEL',
    'SSO',
  ],
};

@Injectable()
export class TenantService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Public config endpoint (no auth required) ────────────────────────────

  async getPublicConfig(tenantId: string) {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: {
        id: true,
        name: true,
        slug: true,
        plan: true,
        status: true,
        config: {
          select: {
            gymName: true,
            primaryColor: true,
            accentColor: true,
            logoUrl: true,
            faviconUrl: true,
            supportEmail: true,
            websiteUrl: true,
            timezone: true,
            features: true,
          },
        },
      },
    });

    if (!tenant) throw new NotFoundException('Tenant not found');

    const planFeatures = PLAN_FEATURES[tenant.plan] ?? PLAN_FEATURES.STARTER;
    const configFeatures = (tenant.config?.features as Record<string, boolean>) ?? {};

    // Merge plan-level features with admin overrides
    const features = planFeatures.reduce<Record<string, boolean>>((acc, f) => {
      acc[f] = configFeatures[f] ?? true;
      return acc;
    }, {});

    return {
      tenantId: tenant.id,
      gymName: tenant.config?.gymName ?? tenant.name,
      primaryColor: tenant.config?.primaryColor ?? '#00D4FF',
      accentColor: tenant.config?.accentColor ?? '#00FF88',
      logoUrl: tenant.config?.logoUrl ?? null,
      faviconUrl: tenant.config?.faviconUrl ?? null,
      supportEmail: tenant.config?.supportEmail ?? null,
      websiteUrl: tenant.config?.websiteUrl ?? null,
      timezone: tenant.config?.timezone ?? 'Europe/Berlin',
      plan: tenant.plan,
      features,
    };
  }

  // ── Tenant admin operations ──────────────────────────────────────────────

  async updateConfig(tenantId: string, dto: UpdateTenantConfigDto) {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { id: true },
    });
    if (!tenant) throw new NotFoundException('Tenant not found');

    return this.prisma.tenantConfig.upsert({
      where: { tenantId },
      create: {
        tenantId,
        gymName: dto.gymName ?? 'My Gym',
        primaryColor: dto.primaryColor ?? '#00D4FF',
        accentColor: dto.accentColor ?? '#00FF88',
        logoUrl: dto.logoUrl,
        supportEmail: dto.supportEmail,
        websiteUrl: dto.websiteUrl,
        timezone: dto.timezone ?? 'Europe/Berlin',
      },
      update: {
        ...(dto.gymName && { gymName: dto.gymName }),
        ...(dto.primaryColor && { primaryColor: dto.primaryColor }),
        ...(dto.accentColor && { accentColor: dto.accentColor }),
        ...(dto.logoUrl !== undefined && { logoUrl: dto.logoUrl }),
        ...(dto.supportEmail !== undefined && { supportEmail: dto.supportEmail }),
        ...(dto.websiteUrl !== undefined && { websiteUrl: dto.websiteUrl }),
        ...(dto.timezone && { timezone: dto.timezone }),
      },
    });
  }

  hasFeature(features: Record<string, boolean>, flag: string): boolean {
    return features[flag] === true;
  }

  // ── SuperAdmin operations ────────────────────────────────────────────────

  async create(dto: CreateTenantDto) {
    const existing = await this.prisma.tenant.findUnique({
      where: { slug: dto.slug },
    });
    if (existing) {
      throw new ConflictException(`Slug "${dto.slug}" is already taken`);
    }

    const trialEndsAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);

    return this.prisma.$transaction(async (tx) => {
      const tenant = await tx.tenant.create({
        data: {
          name: dto.name,
          slug: dto.slug,
          status: 'TRIAL',
          plan: 'STARTER',
          trialEndsAt,
        },
      });

      await tx.tenantConfig.create({
        data: {
          tenantId: tenant.id,
          gymName: dto.gymName,
          supportEmail: dto.supportEmail,
        },
      });

      return tenant;
    });
  }

  async findAll(params: { page: number; limit: number; search?: string }) {
    const skip = (params.page - 1) * params.limit;
    const where = params.search
      ? {
          OR: [
            { name: { contains: params.search, mode: 'insensitive' as const } },
            { slug: { contains: params.search, mode: 'insensitive' as const } },
          ],
        }
      : {};

    const [total, tenants] = await Promise.all([
      this.prisma.tenant.count({ where }),
      this.prisma.tenant.findMany({
        where,
        skip,
        take: params.limit,
        orderBy: { createdAt: 'desc' },
        include: { config: { select: { gymName: true } }, _count: { select: { users: true } } },
      }),
    ]);

    return { total, page: params.page, limit: params.limit, data: tenants };
  }

  async findOne(tenantId: string) {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      include: { config: true, _count: { select: { users: true, plans: true, devices: true } } },
    });
    if (!tenant) throw new NotFoundException('Tenant not found');
    return tenant;
  }

  async updatePlan(tenantId: string, plan: string) {
    return this.prisma.tenant.update({
      where: { id: tenantId },
      data: { plan: plan as any },
    });
  }

  async updateStatus(tenantId: string, status: string) {
    return this.prisma.tenant.update({
      where: { id: tenantId },
      data: { status: status as any },
    });
  }

  async getPlatformStats() {
    const [total, byPlan, byStatus, recentTenants] = await Promise.all([
      this.prisma.tenant.count(),
      this.prisma.tenant.groupBy({ by: ['plan'], _count: { id: true } }),
      this.prisma.tenant.groupBy({ by: ['status'], _count: { id: true } }),
      this.prisma.tenant.findMany({
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: { id: true, name: true, slug: true, plan: true, status: true, createdAt: true },
      }),
    ]);

    return {
      totalTenants: total,
      byPlan: byPlan.map((r) => ({ plan: r.plan, count: r._count.id })),
      byStatus: byStatus.map((r) => ({ status: r.status, count: r._count.id })),
      recentTenants,
    };
  }
}
