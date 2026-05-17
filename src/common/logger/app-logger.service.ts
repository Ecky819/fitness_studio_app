import { Injectable, LoggerService } from '@nestjs/common';
import * as winston from 'winston';

const { combine, timestamp, errors, json, colorize, simple } = winston.format;

function createWinstonLogger(level: string, isProd: boolean) {
    return winston.createLogger({
        level,
        format: combine(
            errors({ stack: true }),
            timestamp(),
            json(),
        ),
        defaultMeta: { service: 'fitness-studio-api' },
        transports: [
            isProd
                ? new winston.transports.Console({ format: combine(timestamp(), json()) })
                : new winston.transports.Console({ format: combine(colorize(), simple()) }),
        ],
    });
}

@Injectable()
export class AppLoggerService implements LoggerService {
    private readonly logger: winston.Logger;

    constructor() {
        const level = process.env.LOG_LEVEL ?? 'info';
        const isProd = process.env.NODE_ENV === 'production';
        this.logger = createWinstonLogger(level, isProd);
    }

    log(message: string, context?: string) {
        this.logger.info(message, { context });
    }

    error(message: string, trace?: string, context?: string) {
        this.logger.error(message, { trace, context });
    }

    warn(message: string, context?: string) {
        this.logger.warn(message, { context });
    }

    debug(message: string, context?: string) {
        this.logger.debug(message, { context });
    }

    verbose(message: string, context?: string) {
        this.logger.verbose(message, { context });
    }

    // Structured access log — called from the logging interceptor.
    logHttp(data: {
        method: string;
        url: string;
        statusCode: number;
        duration: number;
        requestId: string;
        tenantSlug?: string;
    }) {
        this.logger.info('http_request', data);
    }
}
