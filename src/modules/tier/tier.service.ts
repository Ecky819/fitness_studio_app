import {
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SaasPlan } from '@prisma/client';
import Stripe from 'stripe';
import { PrismaService } from '../../prisma/prisma.service';
import {
  TIER_LIMITS,
  SAAS_STRIPE_PRICE_ENV_KEYS,
  isPlanAtLeast,
  PLAN_ORDER,
} from './tier.constants';

export type LimitType = 'doors' | 'members' | 'adminUsers';

@Injectable()
export class TierService {
  private readonly logger = new Logger(TierService.name);
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

  // ── Usage & Limits ────────────────────────────────────────────────────────

  async getCurrentLimits(tenantId: string) {
    const tenant = await this.resolveTenant(tenantId);
    const limits = TIER_LIMITS[tenant.plan];
    const usage = await this.getUsage(tenantId);

    return {
      plan: tenant.plan,
      status: tenant.status,
      limits: {
        maxDoors: limits.maxDoors === Infinity ? null : limits.maxDoors,
        maxMembers: limits.maxMembers === Infinity ? null : limits.maxMembers,
        maxAdminUsers: limits.maxAdminUsers === Infinity ? null : limits.maxAdminUsers,
        logRetentionDays: limits.logRetentionDays,
      },
      usage,
      nextPlan: this.getNextPlan(tenant.plan),
    };
  }

  async getUsage(tenantId: string) {
    const [doors, members, admins] = await Promise.all([
      this.prisma.device.count({
        where: { tenantId, type: 'DOOR_CONTROLLER' },
      }),
      this.prisma.user.count({
        where: { tenantId, isBlocked: false, role: 'USER' },
      }),
      this.prisma.user.count({
        where: { tenantId, role: { in: ['ADMIN', 'TRAINER'] } },
      }),
    ]);
    return { doors, members, adminUsers: admins };
  }

  /**
   * Throws ForbiddenException if the tenant has reached the plan limit for
   * the given resource type. Call this before creating new doors/members.
   */
  async enforceLimit(tenantId: string, type: LimitType): Promise<void> {
    const tenant = await this.resolveTenant(tenantId);
    const limits = TIER_LIMITS[tenant.plan];
    const usage = await this.getUsage(tenantId);

    const limit = type === 'doors'
      ? limits.maxDoors
      : type === 'members'
        ? limits.maxMembers
        : limits.maxAdminUsers;

    const current = type === 'doors'
      ? usage.doors
      : type === 'members'
        ? usage.members
        : usage.adminUsers;

    if (current >= limit) {
      throw new ForbiddenException(
        `${tenant.plan} plan limit reached: ${current}/${limit === Infinity ? '∞' : limit} ${type}. ` +
        `Upgrade to ${this.getNextPlan(tenant.plan) ?? 'ENTERPRISE'} to add more.`,
      );
    }
  }

  /**
   * Returns true if the tenant's current plan is at least the required level.
   * Non-throwing variant for conditional logic.
   */
  async hasPlan(tenantId: string, required: SaasPlan): Promise<boolean> {
    const tenant = await this.resolveTenant(tenantId);
    return isPlanAtLeast(tenant.plan, required);
  }

  // ── Plan Upgrade ──────────────────────────────────────────────────────────

  /**
   * Creates a Stripe Checkout Session for upgrading the tenant's SaaS plan.
   * Returns the session URL for the operator to complete payment.
   * On successful payment, the webhook updates Tenant.plan and Tenant.stripeSaasSubscriptionId.
   */
  async createUpgradeCheckoutSession(
    tenantId: string,
    newPlan: SaasPlan,
    frontendUrl: string,
  ): Promise<{ url: string }> {
    const tenant = await this.resolveTenant(tenantId);

    if (!isPlanAtLeast(newPlan, tenant.plan) || newPlan === tenant.plan) {
      throw new ForbiddenException(
        `Cannot upgrade from ${tenant.plan} to ${newPlan}. Use the downgrade endpoint.`,
      );
    }

    const priceEnvKey = SAAS_STRIPE_PRICE_ENV_KEYS[newPlan];
    if (!priceEnvKey) {
      throw new ForbiddenException('ENTERPRISE plan requires a custom contract. Contact sales.');
    }

    const priceId = this.config.get<string>(priceEnvKey);
    if (!priceId) {
      throw new ForbiddenException(`Stripe price for ${newPlan} is not configured.`);
    }

    const session = await this.stripe.checkout.sessions.create({
      mode: 'subscription',
      line_items: [{ price: priceId, quantity: 1 }],
      payment_method_types: ['card'],
      client_reference_id: tenantId,
      metadata: { type: 'saas_upgrade', tenantId, newPlan },
      ...(tenant.stripeCustomerId && { customer: tenant.stripeCustomerId }),
      success_url: `${frontendUrl}/settings/billing?upgrade=success&plan=${newPlan}`,
      cancel_url: `${frontendUrl}/settings/billing?upgrade=cancelled`,
    });

    return { url: session.url! };
  }

  /**
   * Handles Stripe webhook: checkout.session.completed for SaaS upgrades.
   * Validates the metadata type and updates the tenant's plan.
   */
  async handleUpgradeWebhook(session: Stripe.Checkout.Session): Promise<void> {
    if (session.metadata?.type !== 'saas_upgrade') return;

    const tenantId = session.metadata.tenantId;
    const newPlan = session.metadata.newPlan as SaasPlan;
    const subscriptionId = session.subscription as string;

    if (!tenantId || !newPlan) {
      this.logger.warn('saas_upgrade webhook missing tenantId or newPlan');
      return;
    }

    await this.prisma.tenant.update({
      where: { id: tenantId },
      data: {
        plan: newPlan,
        status: 'ACTIVE',
        ...(subscriptionId && { stripeSaasSubscriptionId: subscriptionId }),
      },
    });

    this.logger.log(`Tenant ${tenantId} upgraded to ${newPlan}`);
  }

  /**
   * Downgrades the tenant's plan after validation.
   * Stripe subscription update is handled separately — this only updates the DB.
   * Call via super-admin or after Stripe subscription.updated webhook.
   */
  async applyPlanChange(tenantId: string, newPlan: SaasPlan): Promise<void> {
    const tenant = await this.resolveTenant(tenantId);

    const currentIdx = PLAN_ORDER.indexOf(tenant.plan);
    const newIdx = PLAN_ORDER.indexOf(newPlan);

    if (newIdx < currentIdx) {
      // Downgrade: enforce that current usage fits within new limits
      const limits = TIER_LIMITS[newPlan];
      const usage = await this.getUsage(tenantId);

      if (usage.doors > limits.maxDoors) {
        throw new ForbiddenException(
          `Cannot downgrade: ${usage.doors} active doors exceed ${newPlan} limit of ${limits.maxDoors}. Remove doors first.`,
        );
      }
      if (usage.members > limits.maxMembers) {
        throw new ForbiddenException(
          `Cannot downgrade: ${usage.members} members exceed ${newPlan} limit of ${limits.maxMembers}.`,
        );
      }
    }

    await this.prisma.tenant.update({ where: { id: tenantId }, data: { plan: newPlan } });
    this.logger.log(`Tenant ${tenantId} plan changed to ${newPlan}`);
  }

  // ── Webhook endpoint (SaaS billing) ───────────────────────────────────────

  /**
   * Validates and processes incoming Stripe webhook events for SaaS billing.
   * This endpoint is separate from the tenant's own billing webhook.
   */
  async handleStripeWebhook(rawBody: Buffer, signature: string): Promise<void> {
    const secret = this.config.getOrThrow<string>('STRIPE_SAAS_WEBHOOK_SECRET');
    let event: Stripe.Event;

    try {
      event = this.stripe.webhooks.constructEvent(rawBody, signature, secret);
    } catch {
      throw new ForbiddenException('Invalid Stripe webhook signature');
    }

    switch (event.type) {
      case 'checkout.session.completed':
        await this.handleUpgradeWebhook(event.data.object as Stripe.Checkout.Session);
        break;

      case 'customer.subscription.deleted': {
        const sub = event.data.object as Stripe.Subscription;
        const tenant = await this.prisma.tenant.findFirst({
          where: { stripeSaasSubscriptionId: sub.id },
        });
        if (tenant) {
          await this.prisma.tenant.update({
            where: { id: tenant.id },
            data: { plan: 'STARTER', status: 'ACTIVE' },
          });
          this.logger.log(`Tenant ${tenant.id} reverted to STARTER (subscription cancelled)`);
        }
        break;
      }

      case 'customer.subscription.updated': {
        const sub = event.data.object as Stripe.Subscription;
        if (sub.status === 'past_due' || sub.status === 'unpaid') {
          const tenant = await this.prisma.tenant.findFirst({
            where: { stripeSaasSubscriptionId: sub.id },
          });
          if (tenant) {
            await this.prisma.tenant.update({
              where: { id: tenant.id },
              data: { status: 'SUSPENDED' },
            });
            this.logger.warn(`Tenant ${tenant.id} suspended due to SaaS payment failure`);
          }
        }
        break;
      }
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  private async resolveTenant(tenantId: string) {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { id: true, plan: true, status: true, stripeCustomerId: true, stripeSaasSubscriptionId: true },
    });
    if (!tenant) throw new NotFoundException('Tenant not found');
    return tenant;
  }

  private getNextPlan(current: SaasPlan): SaasPlan | null {
    const idx = PLAN_ORDER.indexOf(current);
    return PLAN_ORDER[idx + 1] ?? null;
  }
}
