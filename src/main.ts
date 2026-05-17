// Sentry must be the very first import so it can instrument all subsequent modules.
import { initSentry } from './common/sentry/sentry.init';
initSentry();

import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { WsAdapter } from '@nestjs/platform-ws';
import { json } from 'body-parser';
import { randomUUID } from 'crypto';
import { Request, Response, NextFunction } from 'express';
import { AppModule } from './app.module';
import { ConfigService } from '@nestjs/config';
import { AppLoggerService } from './common/logger/app-logger.service';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';

async function bootstrap() {
    const app = await NestFactory.create(AppModule, {
        bufferLogs: true,
    });

    const logger = app.get(AppLoggerService);
    app.useLogger(logger);

    const configService = app.get(ConfigService);

    // Correlation ID middleware — every request gets a traceable X-Request-ID.
    app.use((req: Request, res: Response, next: NextFunction) => {
        const id = (req.headers['x-request-id'] as string) ?? randomUUID();
        req.headers['x-request-id'] = id;
        res.setHeader('x-request-id', id);
        next();
    });

    app.use(
        json({
            verify: (req, _res, buf) => {
                (req as any).rawBody = buf;
            },
        }),
    );

    // Native WebSocket adapter for the OccupancyGateway
    app.useWebSocketAdapter(new WsAdapter(app));

    app.useGlobalPipes(
        new ValidationPipe({
            whitelist: true,
            transform: true,
            forbidNonWhitelisted: true,
        }),
    );

    app.useGlobalInterceptors(new LoggingInterceptor(logger));

    app.setGlobalPrefix('api', {
        // Health + readiness probes must NOT carry the /api prefix so
        // orchestrators (K8s, Docker) can reach them without auth headers.
        exclude: ['health', 'ready'],
    });

    const port = configService.get<number>('PORT') ?? 3000;
    const env = configService.get<string>('NODE_ENV') ?? 'development';

    await app.listen(port);
    logger.log(`🚀 NextGen Gym OS running on http://localhost:${port}/api  [${env}]`, 'Bootstrap');
}

bootstrap();
