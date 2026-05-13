import { BadRequestException, HttpException, Inject, Injectable, InternalServerErrorException, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { randomUUID, createHmac } from 'crypto';
import Redis from 'ioredis';
import { PrismaService } from '../../prisma/prisma.service';

interface AccessTokenPayload {
    sub: string;
    grantId: string;
    doorId: string;
    jti: string;
    iat: number;
    nbf: number;
    exp?: number;
    deviceId?: string;
}

interface StoredTokenMetadata {
    userId: string;
    doorId: string;
    deviceId?: string | null;
}

interface BleChallenge {
    challengeId: string;
    challenge: string;
    doorId: string;
    deviceId: string;
    expiresAt: number;
}

@Injectable()
export class AccessService {
    private readonly accessTokenExpiresIn: string;
    private readonly logger = new Logger(AccessService.name);
    private readonly validationRateLimit: number;
    private readonly validationWindowSeconds: number;
    private readonly accessTokenSecret: string;
    private readonly clockToleranceSeconds: number;

    constructor(
        private readonly jwtService: JwtService,
        private readonly configService: ConfigService,
        private readonly prisma: PrismaService,
        @Inject('REDIS_CLIENT') private readonly redis: Redis,
    ) {
        const accessTokenSecret = this.configService.get<string>('ACCESS_TOKEN_SECRET');
        if (!accessTokenSecret) {
            throw new InternalServerErrorException('ACCESS_TOKEN_SECRET is not configured');
        }

        this.accessTokenSecret = accessTokenSecret;
        this.accessTokenExpiresIn = this.configService.get<string>('ACCESS_TOKEN_EXPIRES_IN') || '60s';
        this.validationRateLimit = Number(this.configService.get<string>('ACCESS_VALIDATE_RATE_LIMIT')) || 5;
        this.validationWindowSeconds = Number(this.configService.get<string>('ACCESS_VALIDATE_WINDOW_SECONDS')) || 60;
        this.clockToleranceSeconds = Number(this.configService.get<string>('JWT_CLOCK_TOLERANCE_SECONDS')) || 5;
    }

    async generateAccessToken(userId: string, doorId: string, deviceId?: string) {
        if (!userId) {
            throw new BadRequestException('userId is required');
        }

        if (!doorId) {
            throw new BadRequestException('doorId is required');
        }

        const now = new Date();

        const subscription = await this.prisma.subscription.findFirst({
            where: { userId, status: 'ACTIVE', validUntil: { gt: now } },
            orderBy: { validUntil: 'desc' },
        });

        if (!subscription) {
            throw new UnauthorizedException('No active subscription found');
        }

        const grant = await this.prisma.accessGrant.findFirst({
            where: { userId, active: true, validUntil: { gt: now } },
            orderBy: { validUntil: 'desc' },
        });

        if (!grant) {
            throw new UnauthorizedException('No active access grant found');
        }

        if (grant.userId !== userId) {
            throw new UnauthorizedException('Access grant does not belong to the authenticated user');
        }

        const jti = randomUUID();
        const redisKey = `access_token:${jti}`;
        const tokenMetadata: StoredTokenMetadata = { userId, doorId, deviceId: deviceId ?? null };

        try {
            await this.redis.set(redisKey, JSON.stringify(tokenMetadata), 'EX', 60);
        } catch (error) {
            this.logger.error('Failed to store access token jti in Redis', (error as Error).stack);
            throw new InternalServerErrorException('Could not store access token');
        }

        const nowSeconds = Math.floor(Date.now() / 1000);
        const claims: Record<string, unknown> = {
            sub: userId,
            grantId: grant.id,
            doorId,
            jti,
            iat: nowSeconds,
            nbf: nowSeconds,
        };

        if (deviceId) {
            claims.deviceId = deviceId;
        }

        const token = await this.jwtService.signAsync(claims, {
            secret: this.accessTokenSecret,
            expiresIn: this.accessTokenExpiresIn,
        });

        return {
            token,
            expiresIn: this.accessTokenExpiresIn,
        };
    }

    async validateToken(token: string, doorId: string, ip: string, deviceId?: string) {
        if (!token) {
            throw new BadRequestException('token is required');
        }

        if (!doorId) {
            throw new BadRequestException('doorId is required');
        }

        if (!ip) {
            throw new BadRequestException('request IP is required');
        }

        let payload: AccessTokenPayload;
        try {
            payload = (await this.jwtService.verifyAsync(token, {
                secret: this.accessTokenSecret,
                clockTolerance: this.clockToleranceSeconds,
            })) as AccessTokenPayload;
        } catch (error) {
            const reason = (error as Error)?.name === 'TokenExpiredError' ? 'expired' : 'invalid_token';
            this.logger.warn(`Access validation failed: ${reason}`);
            throw new UnauthorizedException('Invalid or expired access token');
        }

        if (!payload?.sub || !payload?.grantId || !payload?.doorId || !payload?.jti || typeof payload.iat !== 'number' || typeof payload.nbf !== 'number') {
            await this.logAccessAttempt(payload?.sub ?? 'unknown', doorId, null, false, 'missing_required_claims');
            throw new UnauthorizedException('Access token missing required claims');
        }

        if (payload.doorId !== doorId) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'door_mismatch');
            throw new UnauthorizedException('Access token not valid for this door');
        }

        if (payload.deviceId && deviceId !== payload.deviceId) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'device_mismatch');
            throw new UnauthorizedException('Access token not valid for this device');
        }

        await this.checkRateLimit(doorId, ip);

        const tokenKey = `access_token:${payload.jti}`;
        const script = `
            local token = redis.call('GET', KEYS[1])
            if not token then
                return nil
            end
            redis.call('DEL', KEYS[1])
            return token
        `;

        const storedTokenJson = await this.redis.eval(script, 1, tokenKey) as string | null;
        if (!storedTokenJson) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'replay');
            throw new UnauthorizedException('Access token replay detected');
        }

        let storedToken: StoredTokenMetadata;
        try {
            storedToken = JSON.parse(storedTokenJson) as StoredTokenMetadata;
        } catch {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'invalid_token_metadata');
            throw new UnauthorizedException('Access token metadata invalid');
        }

        if (storedToken.userId !== payload.sub || storedToken.doorId !== payload.doorId) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'token_metadata_mismatch');
            throw new UnauthorizedException('Access token metadata mismatch');
        }

        if (payload.deviceId && storedToken.deviceId !== payload.deviceId) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'device_metadata_mismatch');
            throw new UnauthorizedException('Access token metadata mismatch');
        }

        const now = new Date();
        const subscription = await this.prisma.subscription.findFirst({
            where: { userId: payload.sub, status: 'ACTIVE', validUntil: { gt: now } },
            orderBy: { validUntil: 'desc' },
        });

        if (!subscription) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'no_active_subscription');
            throw new UnauthorizedException('No active subscription found');
        }

        const grant = await this.prisma.accessGrant.findUnique({ where: { id: payload.grantId } });
        if (!grant || !grant.active || grant.userId !== payload.sub || grant.validUntil <= now) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'no_access_grant');
            throw new UnauthorizedException('No valid access grant found');
        }

        await this.logAccessAttempt(payload.sub, doorId, payload.grantId, true, 'access_granted');
        return { access: true };
    }

    async generateBleChallenge(doorId: string, deviceId: string) {
        if (!doorId) {
            throw new BadRequestException('doorId is required');
        }

        if (!deviceId) {
            throw new BadRequestException('deviceId is required');
        }

        const challengeId = randomUUID();
        const challenge = randomUUID(); // 32-byte random challenge
        const expiresAt = Math.floor(Date.now() / 1000) + 30; // 30 seconds

        const challengeData: BleChallenge = {
            challengeId,
            challenge,
            doorId,
            deviceId,
            expiresAt,
        };

        const redisKey = `ble_challenge:${challengeId}`;
        try {
            await this.redis.set(redisKey, JSON.stringify(challengeData), 'EX', 30);
        } catch (error) {
            this.logger.error('Failed to store BLE challenge in Redis', (error as Error).stack);
            throw new InternalServerErrorException('Could not store BLE challenge');
        }

        return {
            challengeId,
            challenge,
            expiresIn: 30,
        };
    }

    async verifyBleChallenge(challengeId: string, signedChallenge: string, doorId: string, deviceId: string) {
        if (!challengeId) {
            throw new BadRequestException('challengeId is required');
        }

        if (!signedChallenge) {
            throw new BadRequestException('signedChallenge is required');
        }

        if (!doorId) {
            throw new BadRequestException('doorId is required');
        }

        if (!deviceId) {
            throw new BadRequestException('deviceId is required');
        }

        const redisKey = `ble_challenge:${challengeId}`;
        const challengeJson = await this.redis.get(redisKey);
        if (!challengeJson) {
            throw new UnauthorizedException('BLE challenge not found or expired');
        }

        let challengeData: BleChallenge;
        try {
            challengeData = JSON.parse(challengeJson) as BleChallenge;
        } catch {
            throw new UnauthorizedException('Invalid BLE challenge data');
        }

        if (challengeData.doorId !== doorId || challengeData.deviceId !== deviceId) {
            throw new UnauthorizedException('BLE challenge does not match door/device');
        }

        // Delete challenge to prevent replay
        await this.redis.del(redisKey);

        // Parse signed challenge: format is "token.signature"
        const parts = signedChallenge.split('.');
        if (parts.length !== 2) {
            throw new UnauthorizedException('Invalid signed challenge format');
        }

        const token = parts[0];
        const signature = parts[1];

        // Verify the access token
        let payload: AccessTokenPayload;
        try {
            payload = (await this.jwtService.verifyAsync(token, {
                secret: this.accessTokenSecret,
                clockTolerance: this.clockToleranceSeconds,
            })) as AccessTokenPayload;
        } catch (error) {
            const reason = (error as Error)?.name === 'TokenExpiredError' ? 'expired' : 'invalid_token';
            this.logger.warn(`BLE challenge verification failed: ${reason}`);
            throw new UnauthorizedException('Invalid or expired access token');
        }

        // Verify signature: HMAC-SHA256 of challenge using token as key
        const expectedSignature = createHmac('sha256', token)
            .update(challengeData.challenge)
            .digest('hex');

        if (signature !== expectedSignature) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'ble_signature_invalid');
            throw new UnauthorizedException('Invalid BLE challenge signature');
        }

        // Validate user access (same logic as QR validation)
        if (!payload?.sub || !payload?.grantId || !payload?.doorId || !payload?.jti || typeof payload.iat !== 'number' || typeof payload.nbf !== 'number') {
            await this.logAccessAttempt(payload?.sub ?? 'unknown', doorId, null, false, 'missing_required_claims');
            throw new UnauthorizedException('Access token missing required claims');
        }

        if (payload.doorId !== doorId) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'door_mismatch');
            throw new UnauthorizedException('Access token not valid for this door');
        }

        if (payload.deviceId && deviceId !== payload.deviceId) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'device_mismatch');
            throw new UnauthorizedException('Access token not valid for this device');
        }

        // Check rate limit for BLE attempts
        await this.checkRateLimit(doorId, `ble:${deviceId}`);

        // Consume the access token (same as QR)
        const tokenKey = `access_token:${payload.jti}`;
        const script = `
            local token = redis.call('GET', KEYS[1])
            if not token then
                return nil
            end
            redis.call('DEL', KEYS[1])
            return token
        `;

        const storedTokenJson = await this.redis.eval(script, 1, tokenKey) as string | null;
        if (!storedTokenJson) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'replay');
            throw new UnauthorizedException('Access token replay detected');
        }

        let storedToken: StoredTokenMetadata;
        try {
            storedToken = JSON.parse(storedTokenJson) as StoredTokenMetadata;
        } catch {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'invalid_token_metadata');
            throw new UnauthorizedException('Access token metadata invalid');
        }

        if (storedToken.userId !== payload.sub || storedToken.doorId !== payload.doorId) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'token_metadata_mismatch');
            throw new UnauthorizedException('Access token metadata mismatch');
        }

        if (payload.deviceId && storedToken.deviceId !== payload.deviceId) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'device_metadata_mismatch');
            throw new UnauthorizedException('Access token metadata mismatch');
        }

        const now = new Date();
        const subscription = await this.prisma.subscription.findFirst({
            where: { userId: payload.sub, status: 'ACTIVE', validUntil: { gt: now } },
            orderBy: { validUntil: 'desc' },
        });

        if (!subscription) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'no_active_subscription');
            throw new UnauthorizedException('No active subscription found');
        }

        const grant = await this.prisma.accessGrant.findUnique({ where: { id: payload.grantId } });
        if (!grant || !grant.active || grant.userId !== payload.sub || grant.validUntil <= now) {
            await this.logAccessAttempt(payload.sub, doorId, payload.grantId, false, 'no_access_grant');
            throw new UnauthorizedException('No valid access grant found');
        }

        await this.logAccessAttempt(payload.sub, doorId, payload.grantId, true, 'ble_access_granted');
        return { access: true };
    }

    private async checkRateLimit(doorId: string, ip: string) {
        const key = `access_rate:${doorId}:${ip}`;
        const current = await this.redis.incr(key);

        if (current === 1) {
            await this.redis.expire(key, this.validationWindowSeconds);
        }

        if (current > this.validationRateLimit) {
            this.logger.warn(`Rate limit exceeded for door=${doorId} ip=${ip}`);
            throw new HttpException('Too many access validation requests', 429);
        }
    }

    private async logAccessAttempt(
        userId: string,
        doorId: string,
        grantId: string | null,
        success: boolean,
        reason: string,
    ) {
        // AccessAttempt: full audit trail (all attempts, including rejected ones)
        const attemptPromise = this.prisma.accessAttempt.create({
            data: { userId, doorId, grantId, success, reason },
        });

        // AccessEvent: business event log tied to a grant (used by admin stats & analytics)
        // Only created when a valid grant is known so the required FK is satisfied.
        const eventPromise = grantId
            ? this.prisma.accessEvent.create({
                  data: {
                      accessGrantId: grantId,
                      userId,
                      doorId,
                      status: success ? 'GRANTED' : 'DENIED',
                      reason,
                  },
              })
            : Promise.resolve();

        await Promise.all([attemptPromise, eventPromise]);

        // Publish to Redis Stream for the AI/occupancy pipeline (fire-and-forget)
        if (success) {
            void this.publishAccessEvent(userId, doorId, reason);
        }
    }

    private async publishAccessEvent(userId: string, doorId: string, reason: string) {
        try {
            // Look up tenantId from user — needed by downstream consumers
            const user = await this.prisma.user.findUnique({
                where: { id: userId },
                select: { tenantId: true },
            });
            if (!user) return;

            // xadd appends to the stream; consumers read via xreadgroup
            await this.redis.xadd(
                `gym_events:${user.tenantId}`,
                '*', // auto-generated ID
                'type', 'access_granted',
                'userId', userId,
                'doorId', doorId,
                'reason', reason ?? '',
                'ts', Date.now().toString(),
            );
        } catch {
            // Stream publish failure must never block door access
        }
    }
}
