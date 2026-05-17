import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import Stripe from 'stripe';
import { PrismaService } from '../../prisma/prisma.service';
import { IsString } from 'class-validator';

export class EnableMeteredBillingDto {
  /** Stripe subscription item ID (si_xxx) for the metered access price */
  @IsString()
  stripeMeteredItemId: string;
}

/**
 * Usage-Based Billing
 *
 * Tenants on metered plans are charged per gym access per month.
 * This service counts successful access attempts and reports them to Stripe
 * at the start of each billing period so Stripe can invoice the correct amount.
 *
 * Setup (in Stripe Dashboard):
 *   1. Create a metered Price with unit_amount and recurring.usage_type = 'metered'
 *   2. Subscribe the tenant to a Subscription that includes this Price
 *   3. Call PATCH /admin/billing/metered/:subscriptionId to store the subscription item ID
 *
 * Reporting happens automatically on the 1st of each month.
 */
@Injectable()
export class UsageBillingService {
  private readonly logger = new Logger(UsageBillingService.name);
  private readonly stripe: Stripe;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {
    this.stripe = new Stripe(
      this.config.getOrThrow<string>('STRIPE_SECRET_KEY'),
      { apiVersion: '2022-11-15' },
    );
  }

  /**
   * Enable metered billing for an existing subscription.
   * Stores the Stripe subscription item ID (si_xxx) so the monthly cron
   * knows which meter to report against.
   */
  async enableMeteredBilling(subscriptionId: string, tenantId: string, dto: EnableMeteredBillingDto) {
    const sub = await this.prisma.subscription.findFirst({
      where: { id: subscriptionId, user: { tenantId } },
    });
    if (!sub) throw new NotFoundException('Subscription not found');

    return this.prisma.subscription.update({
      where: { id: subscriptionId },
      data: { stripeMeteredItemId: dto.stripeMeteredItemId },
      select: { id: true, stripeId: true, stripeMeteredItemId: true },
    });
  }

  /**
   * Report usage for a single tenant to Stripe.
   * Counts successful access attempts in the current calendar month.
   */
  async reportUsageForTenant(tenantId: string): Promise<{ reported: number } | null> {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    // Find all metered subscriptions for this tenant
    const subs = await this.prisma.subscription.findMany({
      where: {
        stripeMeteredItemId: { not: null },
        user: { tenantId },
        status: 'ACTIVE',
      },
      select: { stripeMeteredItemId: true, userId: true },
    });

    if (subs.length === 0) return null;

    // Count successful access events this month for all users in this tenant
    const tenantUserIds = subs.map((s) => s.userId);

    const count = await this.prisma.accessAttempt.count({
      where: {
        tenantId,
        userId: { in: tenantUserIds },
        success: true,
        createdAt: { gte: monthStart },
      },
    });

    // Report to each metered subscription item (typically one per tenant)
    const reported = new Set<string>();
    for (const sub of subs) {
      const itemId = sub.stripeMeteredItemId!;
      if (reported.has(itemId)) continue;

      await this.stripe.subscriptionItems.createUsageRecord(itemId, {
        quantity: count,
        timestamp: Math.floor(now.getTime() / 1000),
        action: 'set',  // 'set' overwrites; 'increment' would add to existing
      });

      reported.add(itemId);
      this.logger.log(`Usage reported: tenant=${tenantId} item=${itemId} count=${count}`);
    }

    return { reported: count };
  }

  /**
   * Monthly cron: runs at 00:05 on the 1st of every month.
   * Reports last month's access count to Stripe for all metered tenants.
   */
  @Cron('5 0 1 * *')
  async reportMonthlyUsage() {
    this.logger.log('Monthly usage reporting started');

    const tenantsWithMetered = await this.prisma.subscription
      .findMany({
        where: { stripeMeteredItemId: { not: null }, status: 'ACTIVE' },
        select: { user: { select: { tenantId: true } } },
        distinct: ['userId'],
      })
      .then((rows) => [...new Set(rows.map((r) => r.user.tenantId))]);

    let success = 0;
    let failed = 0;

    for (const tenantId of tenantsWithMetered) {
      try {
        const result = await this.reportUsageForTenant(tenantId);
        if (result) success++;
      } catch (err) {
        this.logger.error(`Usage report failed for tenant=${tenantId}`, (err as Error).message);
        failed++;
      }
    }

    this.logger.log(`Monthly usage report done: ${success} ok, ${failed} failed`);
  }

  /**
   * Admin view: current month's access count for a tenant.
   * Used in the admin dashboard to preview the upcoming invoice.
   */
  async getCurrentMonthUsage(tenantId: string): Promise<{ tenantId: string; count: number; month: string }> {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const count = await this.prisma.accessAttempt.count({
      where: { tenantId, success: true, createdAt: { gte: monthStart } },
    });

    return {
      tenantId,
      count,
      month: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`,
    };
  }
}
