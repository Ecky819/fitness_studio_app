import { Test, TestingModule } from '@nestjs/testing';
import { BillingService } from '../src/modules/billing/billing.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { InvoiceService } from '../src/modules/invoice/invoice.service';
import { NotificationsService } from '../src/modules/notifications/notifications.service';
import { ConfigService } from '@nestjs/config';

describe('BillingService', () => {
  let service: BillingService;
  const mockPrisma = {
    plan: { findUnique: jest.fn() },
    user: { findUnique: jest.fn() },
  };
  const mockInvoiceService = {
    createInvoice: jest.fn(),
  };
  const mockNotificationsService = {
    sendPaymentFailedNotification: jest.fn(),
  };
  const mockConfig = {
    get: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    mockConfig.get.mockImplementation((key: string) => {
      switch (key) {
        case 'STRIPE_SECRET_KEY':
          return 'sk_test_123';
        case 'FRONTEND_URL':
          return 'http://localhost:3000';
        default:
          return undefined;
      }
    });

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BillingService,
        {
          provide: PrismaService,
          useValue: mockPrisma,
        },
        {
          provide: InvoiceService,
          useValue: mockInvoiceService,
        },
        {
          provide: NotificationsService,
          useValue: mockNotificationsService,
        },
        {
          provide: ConfigService,
          useValue: mockConfig,
        },
      ],
    }).compile();

    service = module.get<BillingService>(BillingService);
  });

  it('should throw when plan does not exist', async () => {
    mockPrisma.plan.findUnique.mockResolvedValue(null);
    mockPrisma.user.findUnique.mockResolvedValue({ id: 'user-id', email: 'test@example.com' });

    await expect(service.createCheckoutSession('invalid-plan', 'user-id')).rejects.toThrow();
  });

  it('should create a checkout session for valid plan and user', async () => {
    mockPrisma.plan.findUnique.mockResolvedValue({ id: 'plan-id', stripePriceId: 'price_123' });
    mockPrisma.user.findUnique.mockResolvedValue({ id: 'user-id', email: 'test@example.com' });
    const mockSession = { id: 'session_123' };
    (service as any).stripe = {
      checkout: {
        sessions: {
          create: jest.fn().mockResolvedValue(mockSession),
        },
      },
    };

    const result = await service.createCheckoutSession('plan-id', 'user-id');

    expect(result).toBe(mockSession);
    expect((service as any).stripe.checkout.sessions.create).toHaveBeenCalledWith({
      mode: 'subscription',
      customer_email: 'test@example.com',
      client_reference_id: 'user-id',
      line_items: [{ price: 'price_123', quantity: 1 }],
      payment_method_types: ['card'],
      subscription_data: {
        metadata: {
          planId: 'plan-id',
          userId: 'user-id',
        },
      },
      success_url: 'http://localhost:3000/success',
      cancel_url: 'http://localhost:3000/cancel',
    });
  });
});
