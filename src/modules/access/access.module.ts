import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AccessController } from './access.controller';
import { AccessService } from './access.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { redisProvider } from './redis.provider';

@Module({
    imports: [
        ConfigModule,
        PrismaModule,
        AuthModule,
        JwtModule.registerAsync({
            imports: [ConfigModule],
            inject: [ConfigService],
            useFactory: async (configService: ConfigService) => {
                const secret = configService.get<string>('ACCESS_TOKEN_SECRET');
                if (!secret) {
                    throw new Error('ACCESS_TOKEN_SECRET is not configured');
                }

                return {
                    secret,
                    signOptions: { expiresIn: configService.get<string>('ACCESS_TOKEN_EXPIRES_IN') || '45s' },
                };
            },
        }),
    ],
    controllers: [AccessController],
    providers: [AccessService, redisProvider],
})
export class AccessModule { }
