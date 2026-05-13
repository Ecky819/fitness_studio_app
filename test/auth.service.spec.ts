import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from '../src/modules/auth/auth.service';
import { PrismaService } from '../src/prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { EmailService } from '../src/modules/notifications/email.service';
import { BadRequestException, UnauthorizedException } from '@nestjs/common';

describe('AuthService', () => {
  let service: AuthService;

  const mockPrisma = {
    user: {
      findUnique: jest.fn(),
      findUniqueOrThrow: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    passwordResetToken: {
      findUnique: jest.fn(),
      create: jest.fn(),
      delete: jest.fn(),
      deleteMany: jest.fn(),
    },
  };

  const mockJwtService = {
    signAsync: jest.fn(),
    verifyAsync: jest.fn(),
  };

  // Use getOrThrow (matches production code after Phase 1 fix)
  const mockConfig = {
    getOrThrow: jest.fn((key: string) => {
      const cfg: Record<string, string> = {
        JWT_ACCESS_SECRET: 'test-access-secret-32-chars-min!!',
        JWT_REFRESH_SECRET: 'test-refresh-secret-32-chars-min!',
      };
      if (!(key in cfg)) throw new Error(`Missing env: ${key}`);
      return cfg[key];
    }),
    get: jest.fn((key: string) => {
      const cfg: Record<string, string> = {
        JWT_ACCESS_EXPIRES_IN: '15m',
        JWT_REFRESH_EXPIRES_IN: '7d',
        FRONTEND_URL: 'http://localhost:3000',
      };
      return cfg[key];
    }),
  };

  const mockEmailService = {
    sendPasswordResetEmail: jest.fn().mockResolvedValue(undefined),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwtService },
        { provide: ConfigService, useValue: mockConfig },
        { provide: EmailService, useValue: mockEmailService },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
  });

  // ── Register ─────────────────────────────────────────────────────────────

  it('throws BadRequestException when email already exists', async () => {
    mockPrisma.user.findUnique.mockResolvedValue({ id: '1', email: 'test@example.com' });

    await expect(
      service.register({ email: 'test@example.com', password: 'password' } as any),
    ).rejects.toThrow(BadRequestException);
  });

  it('creates user and returns tokens on successful register', async () => {
    mockPrisma.user.findUnique.mockResolvedValue(null);
    mockPrisma.user.create.mockResolvedValue({ id: 'new-user-id' });
    mockPrisma.user.findUniqueOrThrow.mockResolvedValue({ role: 'USER' });
    mockPrisma.user.update.mockResolvedValue({});
    mockJwtService.signAsync
      .mockResolvedValueOnce('access-token')
      .mockResolvedValueOnce('refresh-token');

    const result = await service.register({
      email: 'new@example.com',
      password: 'StrongPass1',
    } as any);

    expect(result).toEqual({ accessToken: 'access-token', refreshToken: 'refresh-token' });
    expect(mockPrisma.user.create).toHaveBeenCalledOnce?.();
  });

  // ── Login ─────────────────────────────────────────────────────────────────

  it('throws UnauthorizedException for unknown email', async () => {
    mockPrisma.user.findUnique.mockResolvedValue(null);

    await expect(
      service.login({ email: 'missing@example.com', password: 'password' } as any),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('throws UnauthorizedException for wrong password', async () => {
    const bcrypt = await import('bcrypt');
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(false as never);
    mockPrisma.user.findUnique.mockResolvedValue({
      id: '1',
      email: 'test@example.com',
      password: '$2b$10$hashed',
      isBlocked: false,
    });

    await expect(
      service.login({ email: 'test@example.com', password: 'wrong' } as any),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('throws UnauthorizedException for blocked user', async () => {
    const bcrypt = await import('bcrypt');
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(true as never);
    mockPrisma.user.findUnique.mockResolvedValue({
      id: '1',
      email: 'blocked@example.com',
      password: '$2b$10$hashed',
      isBlocked: true,
    });

    await expect(
      service.login({ email: 'blocked@example.com', password: 'password' } as any),
    ).rejects.toThrow(UnauthorizedException);
  });

  it('returns auth tokens for valid credentials', async () => {
    const bcrypt = await import('bcrypt');
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(true as never);
    mockPrisma.user.findUnique.mockResolvedValue({
      id: '1',
      email: 'test@example.com',
      password: '$2b$10$hashed',
      isBlocked: false,
    });
    mockPrisma.user.findUniqueOrThrow.mockResolvedValue({ role: 'USER' });
    mockPrisma.user.update.mockResolvedValue({});
    mockJwtService.signAsync
      .mockResolvedValueOnce('access-token')
      .mockResolvedValueOnce('refresh-token');

    const result = await service.login({
      email: 'test@example.com',
      password: 'password',
    } as any);

    expect(result).toEqual({ accessToken: 'access-token', refreshToken: 'refresh-token' });
  });

  // ── Password Reset ─────────────────────────────────────────────────────────

  it('forgotPassword returns safe message regardless of email existence', async () => {
    mockPrisma.user.findUnique.mockResolvedValue(null);

    const result = await service.forgotPassword({ email: 'ghost@test.com' });

    expect(result.message).toContain('If that email');
    expect(mockEmailService.sendPasswordResetEmail).not.toHaveBeenCalled();
  });

  it('forgotPassword sends reset email when user exists', async () => {
    mockPrisma.user.findUnique.mockResolvedValue({ id: '1', email: 'real@test.com' });
    mockPrisma.passwordResetToken.deleteMany.mockResolvedValue({});
    mockPrisma.passwordResetToken.create.mockResolvedValue({});

    await service.forgotPassword({ email: 'real@test.com' });

    expect(mockEmailService.sendPasswordResetEmail).toHaveBeenCalledWith(
      'real@test.com',
      expect.stringContaining('/reset-password?token='),
    );
  });

  it('resetPassword throws on invalid/expired token', async () => {
    mockPrisma.passwordResetToken.findUnique.mockResolvedValue(null);

    await expect(
      service.resetPassword({ token: '00000000-0000-0000-0000-000000000000', password: 'NewPass123' }),
    ).rejects.toThrow(BadRequestException);
  });

  it('resetPassword succeeds with valid token and updates password', async () => {
    const token = '11111111-1111-1111-1111-111111111111';
    mockPrisma.passwordResetToken.findUnique.mockResolvedValue({
      token,
      email: 'user@test.com',
      expiresAt: new Date(Date.now() + 3_600_000),
    });
    mockPrisma.user.findUnique.mockResolvedValue({ id: 'user-id' });
    mockPrisma.user.update.mockResolvedValue({});
    mockPrisma.passwordResetToken.delete.mockResolvedValue({});

    const result = await service.resetPassword({ token, password: 'NewSecure123' });

    expect(result.message).toContain('Password updated');
    expect(mockPrisma.user.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'user-id' },
        data: expect.objectContaining({ refreshToken: null }),
      }),
    );
    expect(mockPrisma.passwordResetToken.delete).toHaveBeenCalled();
  });
});
