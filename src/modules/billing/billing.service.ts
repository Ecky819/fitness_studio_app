import { BadRequestException, Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';
import { PrismaService } from '../../prisma/prisma.service';
import { InvoiceService } from '../invoice/invoice.service';

@Injectable()
export class BillingService {
    private readonly stripe: Stripe;
    private readonly logger = new Logger(BillingService.name);

    constructor(
        private readonly configService: ConfigService,
        private readonly prisma: PrismaService,
        private readonly invoiceService: InvoiceService,
    ) {
        const stripeKey = this.configService.get<string>('STRIPE_SECRET_KEY');
        if (!stripeKey) {
            throw new InternalServerErrorException('STRIPE_SECRET_KEY is not configured');
        }

        this.stripe = new Stripe(stripeKey, {
            apiVersion: '2022-11-15',
        });
    }

    async createCheckoutSession(planId: string, userId: string) {
        const plan = await this.prisma.plan.findUnique({ where: { id: planId } });
        if (!plan) {
            throw new BadRequestException('Plan not found');
        }

        const user = await this.prisma.user.findUnique({ where: { id: userId } });
        if (!user) {
            throw new BadRequestException('Authenticated user not found');
        }

        return this.stripe.checkout.sessions.create({
            mode: 'subscription',
            customer_email: user.email,
            client_reference_id: user.id,
            line_items: [{ price: plan.stripePriceId, quantity: 1 }],
            payment_method_types: ['card'],
            subscription_data: {
                metadata: {
                    planId: plan.id,
                    userId: user.id,
                },
            },
            success_url: this.configService.get<string>('FRONTEND_URL') || 'https://example.com/success',
            cancel_url: this.configService.get<string>('FRONTEND_URL') || 'https://example.com/cancel',
        });
    }

    async handleWebhook(body: any, signature: string) {
        const webhookSecret = this.configService.get<string>('STRIPE_WEBHOOK_SECRET');
        if (!webhookSecret) {
            this.logger.error('STRIPE_WEBHOOK_SECRET is not configured');
            throw new InternalServerErrorException('Stripe webhook secret is not configured');
        }

        let event: Stripe.Event;
        try {
            event = this.stripe.webhooks.constructEvent(body, signature, webhookSecret);
        } catch (err) {
            this.logger.warn('Invalid webhook signature');
            throw new BadRequestException('Invalid webhook signature');
        }

        const existing = await this.prisma.stripeWebhookEvent.findUnique({ where: { eventId: event.id } });
        if (existing) {
            this.logger.log(`Duplicate webhook event ignored: ${event.id}`);
            return { received: true };
        }

        try {
            switch (event.type) {
                case 'checkout.session.completed':
                    await this.onCheckoutSessionCompleted(event.data.object as Stripe.Checkout.Session);
                    break;
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
                    this.logger.log(`Unhandled event type: ${event.type}`);
            }
        } catch (error) {
            this.logger.error(`Webhook processing failed for ${event.id}`, (error as Error).stack);
            throw new InternalServerErrorException('Webhook handling failed');
        }

        await this.prisma.stripeWebhookEvent.create({
            data: {
                eventId: event.id,
                eventType: event.type,
            },
        });

        return { received: true };
    }

    private mapStripeSubscriptionStatus(status: string) {
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
                throw new InternalServerErrorException(`Unsupported Stripe subscription status: ${status}`);
        }
    }

    private async onCheckoutSessionCompleted(session: Stripe.Checkout.Session) {
        const subscriptionId = typeof session.subscription === 'string' ? session.subscription : session.subscription?.id;
        const planId = session.metadata?.planId;
        const userId = session.metadata?.userId;

        if (!subscriptionId || !planId || !userId) {
            this.logger.warn('Missing required Stripe session metadata');
            throw new BadRequestException('Invalid checkout session metadata');
        }

        const plan = await this.prisma.plan.findUnique({ where: { id: planId } });
        if (!plan) {
            this.logger.warn('Plan from webhook not found');
            throw new BadRequestException('Plan not found');
        }

        const user = await this.prisma.user.findUnique({ where: { id: userId } });
        if (!user) {
            this.logger.warn('Webhook user not found');
            throw new BadRequestException('User not found');
        }

        const stripeSubscription = await this.stripe.subscriptions.retrieve(subscriptionId);
        if (!stripeSubscription.current_period_end) {
            throw new InternalServerErrorException('Stripe subscription is missing current period end');
        }

        const validUntil = new Date(stripeSubscription.current_period_end * 1000);
        const currentPeriodEnd = validUntil;
        const subscriptionStatus = this.mapStripeSubscriptionStatus(stripeSubscription.status);

        await this.prisma.subscription.upsert({
            where: { stripeId: subscriptionId },
            update: {
                status: subscriptionStatus,
                validUntil,
                currentPeriodEnd,
                planId: plan.id,
                userId: user.id,
            },
            create: {
                stripeId: subscriptionId,
                userId: user.id,
                planId: plan.id,
                status: subscriptionStatus,
                validUntil,
                currentPeriodEnd,
            },
        });

        await this.prisma.accessGrant.updateMany({
            where: { userId: user.id, active: true },
            data: { active: false },
        });

        await this.prisma.accessGrant.create({
            data: {
                userId: user.id,
                active: true,
                validUntil,
            },
        });
    }

    private async onInvoicePaymentSucceeded(invoice: Stripe.Invoice) {
        const stripeSubscriptionId = invoice.subscription as string;
        if (!stripeSubscriptionId) {
            this.logger.warn('Invoice payment succeeded event missing subscription id');
            return;
        }

        const subscription = await this.prisma.subscription.findUnique({ where: { stripeId: stripeSubscriptionId } });
        if (!subscription) {
            this.logger.warn('Invoice payment succeeded for unknown subscription id: ' + stripeSubscriptionId);
            return;
        }

        const amountCents = invoice.total ?? invoice.amount_paid ?? 0;
        const currency = invoice.currency ?? 'USD';

        await this.invoiceService.createInvoice({
            userId: subscription.userId,
            subscriptionId: subscription.id,
            amountCents,
            currency,
            invoiceNo: invoice.number ?? undefined,
        });
    }

    private async onInvoicePaymentFailed(invoice: Stripe.Invoice) {
        const stripeSubscriptionId = invoice.subscription as string;
        if (!stripeSubscriptionId) {
            this.logger.warn('Invoice payment failed event missing subscription id');
            return;
        }

        const subscription = await this.prisma.subscription.findUnique({ where: { stripeId: stripeSubscriptionId } });
        if (!subscription) {
            this.logger.warn('Invoice payment failed for unknown subscription id: ' + stripeSubscriptionId);
            return;
        }

        await this.prisma.subscription.update({
            where: { id: subscription.id },
            data: { status: 'PAST_DUE' },
        });

        await this.prisma.accessGrant.updateMany({
            where: { userId: subscription.userId, active: true },
            data: { active: false },
        });
    }

    private async onSubscriptionDeleted(subscription: Stripe.Subscription) {
        const subscriptionRecord = await this.prisma.subscription.findUnique({ where: { stripeId: subscription.id } });
        if (!subscriptionRecord) {
            this.logger.warn('Subscription deleted for unknown subscription id: ' + subscription.id);
            return;
        }

        await this.prisma.subscription.update({
            where: { id: subscriptionRecord.id },
            data: { status: 'CANCELED' },
        });
        await this.prisma.accessGrant.updateMany({
            where: { userId: subscriptionRecord.userId, active: true },
            data: { active: false },
        });
    }
}
