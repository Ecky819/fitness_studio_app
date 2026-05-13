import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { EmailService } from '../notifications/email.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly emailService: EmailService,
  ) {}

  async register(dto: RegisterDto, tenantId: string) {
    const existing = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId, email: dto.email } },
    });
    if (existing) throw new BadRequestException('Email already in use');

    const password = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: { tenantId, email: dto.email, password },
    });

    return this.buildAuthResponse(user.id);
  }

  async login(dto: LoginDto, tenantId: string) {
    const user = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId, email: dto.email } },
    });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const passwordMatches = await bcrypt.compare(dto.password, user.password);
    if (!passwordMatches) throw new UnauthorizedException('Invalid credentials');

    if (user.isBlocked) throw new UnauthorizedException('Account has been suspended');

    return this.buildAuthResponse(user.id);
  }

  async refresh(dto: RefreshTokenDto) {
    const payload = await this.verifyRefreshToken(dto.refreshToken);
    const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user || user.refreshToken !== dto.refreshToken) {
      throw new ForbiddenException('Refresh token invalid');
    }
    return this.buildAuthResponse(user.id);
  }

  async buildAuthResponse(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { role: true, tenantId: true },
    });

    // tenantId embedded in JWT — services read it via TenantContextService
    const accessToken = await this.jwtService.signAsync({
      sub: userId,
      role: user.role,
      tenantId: user.tenantId,
    });
    const refreshToken = await this.createRefreshToken(userId);

    await this.prisma.user.update({
      where: { id: userId },
      data: { refreshToken },
    });

    return { accessToken, refreshToken };
  }

  async createRefreshToken(userId: string) {
    return this.jwtService.signAsync(
      { sub: userId },
      {
        secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
        expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRES_IN') ?? '7d',
      },
    );
  }

  async verifyRefreshToken(token: string) {
    try {
      return this.jwtService.verifyAsync(token, {
        secret: this.configService.getOrThrow<string>('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new ForbiddenException('Refresh token invalid');
    }
  }

  async verifyAccessToken(token: string) {
    if (!token) throw new UnauthorizedException('Missing access token');
    try {
      return await this.jwtService.verifyAsync(token, {
        secret: this.configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Invalid access token');
    }
  }

  // ── Password Reset ──────────────────────────────────────────────────────

  async forgotPassword(dto: ForgotPasswordDto, tenantId: string) {
    const user = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId, email: dto.email } },
    });

    if (!user) {
      this.logger.log(`Password reset for unknown email in tenant ${tenantId}`);
      return { message: 'If that email is registered, a reset link has been sent.' };
    }

    await this.prisma.passwordResetToken.deleteMany({
      where: { tenantId, email: dto.email },
    });

    const token = randomUUID();
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000);

    await this.prisma.passwordResetToken.create({
      data: { tenantId, email: dto.email, token, expiresAt },
    });

    const frontendUrl = this.configService.get<string>('FRONTEND_URL') ?? 'http://localhost:3000';
    await this.emailService.sendPasswordResetEmail(
      dto.email,
      `${frontendUrl}/reset-password?token=${token}`,
    );

    return { message: 'If that email is registered, a reset link has been sent.' };
  }

  async resetPassword(dto: ResetPasswordDto) {
    const record = await this.prisma.passwordResetToken.findUnique({
      where: { token: dto.token },
    });

    if (!record || record.expiresAt < new Date()) {
      if (record) {
        await this.prisma.passwordResetToken.delete({ where: { token: dto.token } });
      }
      throw new BadRequestException('Reset token is invalid or has expired');
    }

    const user = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId: record.tenantId, email: record.email } },
    });
    if (!user) {
      await this.prisma.passwordResetToken.delete({ where: { token: dto.token } });
      throw new BadRequestException('User not found');
    }

    const hashed = await bcrypt.hash(dto.password, 10);

    await Promise.all([
      this.prisma.user.update({
        where: { id: user.id },
        data: { password: hashed, refreshToken: null },
      }),
      this.prisma.passwordResetToken.delete({ where: { token: dto.token } }),
    ]);

    this.logger.log(`Password reset for ${record.email} (tenant ${record.tenantId})`);
    return { message: 'Password updated successfully. Please log in.' };
  }

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        role: true,
        tenantId: true,
        isBlocked: true,
        createdAt: true,
        updatedAt: true,
      },
    });
    if (!user) throw new UnauthorizedException('User not found');
    return user;
  }
}
