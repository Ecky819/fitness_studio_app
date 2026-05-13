import { FactoryProvider } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

export const REDIS_CLIENT = 'REDIS_CLIENT';

export const redisProvider: FactoryProvider = {
    provide: REDIS_CLIENT,
    inject: [ConfigService],
    useFactory: (configService: ConfigService) => {
        const redisUrl = configService.get<string>('REDIS_URL');
        if (redisUrl) {
            return new Redis(redisUrl);
        }

        const host = configService.get<string>('REDIS_HOST') || 'localhost';
        const port = Number(configService.get<string>('REDIS_PORT') || 6379);
        return new Redis({ host, port });
    },
};
