import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';
import { PrismaService } from '../../prisma/prisma.service';
import { InvoiceService } from '../invoice/invoice.service';
import { NotificationsService } from '../notifications/notifications.service';

// Stripe platform fee: 1.5% of each transaction (in basis points = 150)
const PLATFORM_FEE_BPS = 150;

@Injectable()
export class BillingService {
  private readonly stripe: Stripe;
  private readonly logger = new Logger(BillingService.name);

  constructor(
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
    private readonly invoiceService: InvoiceService,
    private readonly notificationsService: NotificationsService,
  ) {
    this.stripe = new Stripe(
      this.configService.getOrThrow<string>('STRIPE_SECRET_KEY'),
      { apiVersion: '2022-11-15' },
    );
  }

  // ── Checkout ────────────────────────────────────────────────────────────────

  async createCheckoutSession(planId: string, userId: string) {
    const [plan, user] = await Promise.all([
      this.prisma.plan.findUnique({ where: { id: planId } }),
      this.prisma.user.findUnique({
        where: { id: userId },
        include: { tenant: { select: { stripeAccountId: true, config: { select: { websiteUrl: true } } } } },
      }),
    ]);

    if (!plan) throw new BadRequestException('Plan not found');
    if (!user) throw new BadRequestException('User not found');

    const frontendUrl = (
      user.tenant.config?.websiteUrl ||
      this.configService.get<string>('FRONTEND_URL') ||
      'https://example.com'
    ).replace(/\/$/, '');

    const sessionParams: Stripe.Checkout.SessionCreateParams = {
      mode: 'subscription',
      customer_email: user.email,
      client_reference_id: user.id,
      line_items: [{ price: plan.stripePriceId, quantity: 1 }],
      payment_method_types: ['card'],
      subscription_data: {
        metadata: { planId: plan.id, userId: user.id, tenantId: user.tenantId },
      },
      success_url: `${frontendUrl}/success`,
      cancel_url: `${frontendUrl}/cancel`,
    };

    // Stripe Connect: route payment to the tenant's connected account
    // and collect a platform fee on each transaction
    if (user.tenant.stripeAccountId) {
      sessionParams.payment_intent_data = {
        application_fee_amount: Math.round(plan.amountCents * PLATFORM_FEE_BPS / 10000),
        transfer_data: { destination: user.tenant.stripeAccountId },
      };
    }

    return this.stripe.checkout.sessions.create(sessionParams);
  }

  // ── Hardware one-time checkout ──────────────────────────────────────────────

  async createHardwareCheckoutSession(
    userId: string,
    stripePriceId: string,
    quantity = 1,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: {
        tenant: {
          select: {
            id: true,
            stripeAccountId: true,
            config: { select: { websiteUrl: true } },
          },
        },
      },
    });
    if (!user) throw new BadRequestException('User not found');

    const frontendUrl = (
      user.tenant.config?.websiteUrl ||
      this.configService.get<string>('FRONTEND_URL') ||
      'https://example.com'
    ).replace(/\/$/, '');

    const sessionParams: Stripe.Checkout.SessionCreateParams = {
      mode: 'payment',
      customer_email: user.email,
      client_reference_id: user.id,
      line_items: [{ price: stripePriceId, quantity }],
      payment_method_types: ['card'],
      payment_intent_data: {
        metadata: {
          type: 'hardware',
          userId: user.id,
          tenantId: user.tenantId,
        },
      },
      success_url: `${frontendUrl}/hardware/success`,
      cancel_url: `${frontendUrl}/hardware/cancel`,
    };

    // Route payment to the tenant's connected Stripe account if present
    if (user.tenant.stripeAccountId) {
      sessionParams.payment_intent_data = {
        ...sessionParams.payment_intent_data,
        application_fee_amount: Math.round(
          (await this.getUnitAmount(stripePriceId)) * quantity * PLATFORM_FEE_BPS / 10000,
        ),
        transfer_data: { destination: user.tenant.stripeAccountId },
      };
    }

    return this.stripe.checkout.sessions.create(sessionParams);
  }

  private async getUnitAmount(stripePriceId: string): Promise<number> {
    const price = await this.stripe.prices.retrieve(stripePriceId);
    return price.unit_amount ?? 0;
  }

  // ── Stripe Connect: onboard a tenant ────────────────────────────────────────

  async createConnectAccountLink(tenantId: string, returnUrl: string) {
    const tenant = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    if (!tenant) throw new NotFoundException('Tenant not found');

    let accountId = tenant.stripeAccountId;

    if (!accountId) {
      // Create a new Express account for this gym
      const account = await this.stripe.accounts.create({
        type: 'express',
        metadata: { tenantId },
      });
      accountId = account.id;

      await this.prisma.tenant.update({
        where: { id: tenantId },
        data: { stripeAccountId: accountId },
      });
    }

    // Generate an onboarding link (expires after ~10 min)
    const link = await this.stripe.accountLinks.create({
      account: accountId,
      refresh_url: `${returnUrl}?refresh=true`,
      return_url: `${returnUrl}?success=true`,
      type: 'account_onboarding',
    });

    return { url: link.url };
  }

  // ── Webhooks ────────────────────────────────────────────────────────────────

  async handleWebhook(body: any, signature: string) {
    const webhookSecret = this.configService.get<string>('STRIPE_WEBHOOK_SECRET');
    if (!webhookSecret) throw new InternalServerErrorException('STRIPE_WEBHOOK_SECRET not configured');

    let event: Stripe.Event;
    try {
      event = this.stripe.webhooks.constructEvent(body, signature, webhookSecret);
    } catch {
      this.logger.warn('Invalid webhook signature');
      throw new BadRequestException('Invalid webhook signature');
    }

    // Extract tenantId from event metadata if present
    const tenantId = this.extractTenantId(event);

    const existing = await this.prisma.stripeWebhookEvent.findUnique({
      where: { eventId: event.id },
    });
    if (existing) {
      this.logger.log(`Duplicate webhook ignored: ${event.id}`);
      return { received: true };
    }

    try {
      switch (event.type) {
        case 'checkout.session.completed': {
          const session = event.data.object as Stripe.Checkout.Session;
          if (session.metadata?.type === 'hardware') {
            await this.onHardwareCheckoutCompleted(session);
          } else {
            await this.onCheckoutSessionCompleted(session);
          }
          break;
        }
        case 'invoice.payment_succeeded':
          await this.onInvoicePaymentSucceeded(event.data.object as Stripe.Invoice);
          break;
        case 'invoice.payment_failed':
          await this.onInvoicePaymentFailed(event.data.object as Stripe.Invoice);
          break;
        case 'customer.subscription.deleted':
          await this.onSubscriptionDeleted(event.data.object as Stripe.Subscription);
          break;
        default:
          this.logger.log(`Unhandled event: ${event.type}`);
      }
    } catch (error) {
      this.logger.error(`Webhook failed for ${event.id}`, (error as Error).stack);
      throw new InternalServerErrorException('Webhook handling failed');
    }

    await this.prisma.stripeWebhookEvent.create({
      data: { eventId: event.id, eventType: event.type, tenantId },
    });

    return { received: true };
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  private extractTenantId(event: Stripe.Event): string | null {
    try {
      const obj = event.data.object as any;
      return (
        obj?.metadata?.tenantId ||
        obj?.subscription_data?.metadata?.tenantId ||
        null
      );
    } catch {
      return null;
    }
  }

  private mapStripeStatus(status: string) {
    switch (status) {
      case 'active':
      case 'trialing':
        return 'ACTIVE';
      case 'past_due':
      case 'unpaid':
      case 'incomplete':
        return 'PAST_DUE';
      case 'canceled':
      case 'incomplete_expired':
      case 'ended':
        return 'CANCELED';
      default:
        throw new InternalServerErrorException(`Unsupported Stripe status: ${status}`);
    }
  }

  private async onHardwareCheckoutCompleted(session: Stripe.Checkout.Session) {
    const { userId, tenantId } = (session.payment_intent_data as any)?.metadata ??
      session.metadata ?? {};

    if (!userId || !tenantId) {
      this.logger.warn(`Hardware checkout missing metadata: ${session.id}`);
      return;
    }

    this.logger.log(`Hardware purchase confirmed: user=${userId} tenant=${tenantId}`);
    // Device provisioning token is generated separately by the admin
    // via POST /admin/devices/provision after the hardware ships.
  }

  private async onCheckoutSessionCompleted(session: Stripe.Checkout.Session) {
    const subscriptionId =
      typeof session.subscription === 'string'
        ? session.subscription
        : session.subscription?.id;
    const { planId, userId, tenantId } = session.metadata ?? {};

    if (!subscriptionId || !planId || !userId) {
      throw new BadRequestException('Missing session metadata');
    }

    const [plan, user] = await Promise.all([
      this.prisma.plan.findUnique({ where: { id: planId } }),
      this.prisma.user.findUnique({ where: { id: userId } }),
    ]);

    if (!plan || !user) throw new BadRequestException('Plan or user not found');

    const stripeSubscription = await this.stripe.subscriptions.retrieve(subscriptionId);
    const validUntil = new Date(stripeSubscription.current_period_end * 1000);
    const status = this.mapStripeStatus(stripeSubscription.status);

    await this.prisma.subscription.upsert({
      where: { stripeId: subscriptionId },
      update: { status: status as any, validUntil, currentPeriodEnd: validUntil, planId: plan.id },
      create: {
        stripeId: subscriptionId,
        userId: user.id,
        planId: plan.id,
        status: status as any,
        validUntil,
        currentPeriodEnd: validUntil,
      },
    });

    await this.prisma.accessGrant.updateMany({
      where: { userId: user.id, active: true },
      data: { active: false },
    });

    await this.prisma.accessGrant.create({
      data: { userId: user.id, active: true, validUntil },
    });
  }

  private async onInvoicePaymentSucceeded(invoice: Stripe.Invoice) {
    const stripeSubId = invoice.subscription as string;
    if (!stripeSubId) return;

    const subscription = await this.prisma.subscription.findUnique({
      where: { stripeId: stripeSubId },
    });
    if (!subscription) return;

    await this.invoiceService.createInvoice({
      userId: subscription.userId,
      subscriptionId: subscription.id,
      amountCents: invoice.total ?? 0,
      currency: invoice.currency ?? 'eur',
      invoiceNo: invoice.number ?? undefined,
    });
  }

  private async onInvoicePaymentFailed(invoice: Stripe.Invoice) {
    const stripeSubId = invoice.subscription as string;
    if (!stripeSubId) return;

    const subscription = await this.prisma.subscription.findUnique({
      where: { stripeId: stripeSubId },
    });
    if (!subscription) return;

    await this.prisma.subscription.update({
      where: { id: subscription.id },
      data: { status: 'PAST_DUE' },
    });
    await this.prisma.accessGrant.updateMany({
      where: { userId: subscription.userId, active: true },
      data: { active: false },
    });

    const amount = invoice.total ? `€${(invoice.total / 100).toFixed(2)}` : 'unknown';
    await this.notificationsService.sendPaymentFailedNotification(subscription.userId, amount);
  }

  private async onSubscriptionDeleted(subscription: Stripe.Subscription) {
    const sub = await this.prisma.subscription.findUnique({
      where: { stripeId: subscription.id },
    });
    if (!sub) return;

    await this.prisma.subscription.update({
      where: { id: sub.id },
      data: { status: 'CANCELED' },
    });
    await this.prisma.accessGrant.updateMany({
      where: { userId: sub.userId, active: true },
      data: { active: false },
    });
    await this.notificationsService.sendAccessRevokedNotification(
      sub.userId,
      'Subscription cancelled',
    );
  }
}
