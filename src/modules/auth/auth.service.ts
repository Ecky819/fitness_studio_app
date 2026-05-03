import { BadRequestException, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';

@Injectable()
export class AuthService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly jwtService: JwtService,
        private readonly configService: ConfigService,
    ) { }

    async register(dto: RegisterDto) {
        const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
        if (existing) {
            throw new BadRequestException('Email already in use');
        }

        const password = await bcrypt.hash(dto.password, 10);
        const user = await this.prisma.user.create({
            data: {
                email: dto.email,
                password,
            },
        });

        return this.buildAuthResponse(user.id);
    }

    async login(dto: LoginDto) {
        const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
        if (!user) {
            throw new UnauthorizedException('Invalid credentials');
        }

        const passwordMatches = await bcrypt.compare(dto.password, user.password);
        if (!passwordMatches) {
            throw new UnauthorizedException('Invalid credentials');
        }

        if (user.isBlocked) {
            throw new UnauthorizedException('Account has been suspended');
        }

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
            select: { role: true },
        });

        // role is embedded so guards never need a DB round-trip per request
        const accessToken = await this.jwtService.signAsync({ sub: userId, role: user.role });
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
                secret: this.configService.get<string>('JWT_REFRESH_SECRET') || 'refreshsecret',
                expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRES_IN') || '7d',
            },
        );
    }

    async verifyRefreshToken(token: string) {
        try {
            return this.jwtService.verifyAsync(token, {
                secret: this.configService.get<string>('JWT_REFRESH_SECRET') || 'refreshsecret',
            });
        } catch (error) {
            throw new ForbiddenException('Refresh token invalid');
        }
    }

    async verifyAccessToken(token: string) {
        if (!token) {
            throw new UnauthorizedException('Missing access token');
        }

        try {
            return await this.jwtService.verifyAsync(token, {
                secret: this.configService.get<string>('JWT_ACCESS_SECRET') || 'supersecret',
            });
        } catch (error) {
            throw new UnauthorizedException('Invalid access token');
        }
    }

    async getProfile(userId: string) {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { id: true, email: true, role: true, isBlocked: true, createdAt: true, updatedAt: true },
        });

        if (!user) {
            throw new UnauthorizedException('User not found');
        }

        return user;
    }
}
