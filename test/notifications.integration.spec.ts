import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

describe('Notifications Integration Test', () => {
    let app: INestApplication;
    let prisma: PrismaService;

    beforeAll(async () => {
        const moduleFixture: TestingModule = await Test.createTestingModule({
            imports: [AppModule],
        }).compile();

        app = moduleFixture.createNestApplication();
        prisma = app.get(PrismaService);
        await app.init();
    });

    afterAll(async () => {
        await app.close();
    });

    it('should send payment failed notification', async () => {
        // Create test user
        const user = await prisma.user.create({
            data: {
                email: 'test@example.com',
                password: 'hashedpassword',
            },
        });

        // Create test subscription
        const subscription = await prisma.subscription.create({
            data: {
                stripeId: 'sub_test_123',
                userId: user.id,
                planId: 'plan_test',
                status: 'ACTIVE',
                validUntil: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
                currentPeriodEnd: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
            },
        });

        // Simulate payment failed webhook
        const webhookPayload = {
            id: 'evt_test_webhook',
            object: 'event',
            type: 'invoice.payment_failed',
            data: {
                object: {
                    subscription: 'sub_test_123',
                    total: 2999, // $29.99
                    currency: 'usd',
                },
            },
        };

        // Mock Stripe webhook signature (simplified for testing)
        const response = await request(app.getHttpServer())
            .post('/api/billing/webhook')
            .set('stripe-signature', 't=1234567890,v1=test_signature')
            .send(JSON.stringify(webhookPayload))
            .expect(200);

        expect(response.body).toHaveProperty('received', true);

        // Verify subscription status changed
        const updatedSubscription = await prisma.subscription.findUnique({
            where: { id: subscription.id },
        });
        expect(updatedSubscription?.status).toBe('PAST_DUE');

        // Verify access grant was revoked
        const accessGrants = await prisma.accessGrant.findMany({
            where: { userId: user.id },
        });
        expect(accessGrants.every(grant => !grant.active)).toBe(true);

        // Clean up
        await prisma.subscription.delete({ where: { id: subscription.id } });
        await prisma.user.delete({ where: { id: user.id } });
    });
});