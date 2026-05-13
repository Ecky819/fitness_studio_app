import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsService } from '../src/modules/notifications/notifications.service';
import { EmailService } from '../src/modules/notifications/email.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { ConfigService } from '@nestjs/config';

const mockQueue = {
    add: jest.fn(),
};

const mockEmailService = {
    sendPaymentFailedNotification: jest.fn(),
    sendAccessRevokedNotification: jest.fn(),
    sendMembershipExpiringNotification: jest.fn(),
};

const mockPrisma = {
    user: {
        findUnique: jest.fn(),
    },
};

describe('NotificationsService', () => {
    let service: NotificationsService;

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                NotificationsService,
                {
                    provide: 'BullQueue_notifications',
                    useValue: mockQueue,
                },
                {
                    provide: EmailService,
                    useValue: mockEmailService,
                },
                {
                    provide: PrismaService,
                    useValue: mockPrisma,
                },
                {
                    provide: ConfigService,
                    useValue: {
                        get: jest.fn(),
                    },
                },
            ],
        }).compile();

        service = module.get<NotificationsService>(NotificationsService);
        jest.clearAllMocks();
    });

    it('should be defined', () => {
        expect(service).toBeDefined();
    });

    it('should enqueue a payment failed notification job', async () => {
        await service.sendPaymentFailedNotification('user-id', '$29.99');

        expect(mockQueue.add).toHaveBeenCalledWith('send-notification', {
            type: 'payment_failed',
            userId: 'user-id',
            data: { amount: '$29.99' },
        });
    });

    it('should enqueue an access revoked notification job', async () => {
        await service.sendAccessRevokedNotification('user-id', 'Payment failed');

        expect(mockQueue.add).toHaveBeenCalledWith('send-notification', {
            type: 'access_revoked',
            userId: 'user-id',
            data: { reason: 'Payment failed' },
        });
    });

    it('should enqueue a membership expiring notification job', async () => {
        await service.sendMembershipExpiringNotification('user-id', 3);

        expect(mockQueue.add).toHaveBeenCalledWith('send-notification', {
            type: 'membership_expiring',
            userId: 'user-id',
            data: { daysLeft: 3 },
        });
    });

    it('should process a payment failed notification job', async () => {
        mockPrisma.user.findUnique.mockResolvedValue({ email: 'test@example.com' });

        await service.processNotification({
            data: { type: 'payment_failed', userId: 'user-id', data: { amount: '$29.99' } },
        });

        expect(mockEmailService.sendPaymentFailedNotification).toHaveBeenCalledWith('test@example.com', 'test', '$29.99');
    });

    it('should process an access revoked notification job', async () => {
        mockPrisma.user.findUnique.mockResolvedValue({ email: 'test@example.com' });

        await service.processNotification({
            data: { type: 'access_revoked', userId: 'user-id', data: { reason: 'Payment failed' } },
        });

        expect(mockEmailService.sendAccessRevokedNotification).toHaveBeenCalledWith('test@example.com', 'test', 'Payment failed');
    });

    it('should process a membership expiring notification job', async () => {
        mockPrisma.user.findUnique.mockResolvedValue({ email: 'test@example.com' });

        await service.processNotification({
            data: { type: 'membership_expiring', userId: 'user-id', data: { daysLeft: 3 } },
        });

        expect(mockEmailService.sendMembershipExpiringNotification).toHaveBeenCalledWith('test@example.com', 'test', 3);
    });
});
