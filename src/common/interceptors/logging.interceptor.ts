import {
    CallHandler,
    ExecutionContext,
    Injectable,
    NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import { Request, Response } from 'express';
import { AppLoggerService } from '../logger/app-logger.service';

@Injectable()
export class LoggingInterceptor implements NestInterceptor {
    constructor(private readonly logger: AppLoggerService) {}

    intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
        const http = context.switchToHttp();
        const req = http.getRequest<Request>();
        const res = http.getResponse<Response>();
        const start = Date.now();

        return next.handle().pipe(
            tap(() => {
                this.logger.logHttp({
                    method: req.method,
                    url: req.originalUrl,
                    statusCode: res.statusCode,
                    duration: Date.now() - start,
                    requestId: req.headers['x-request-id'] as string,
                    tenantSlug: req.headers['x-tenant-slug'] as string | undefined,
                });
            }),
        );
    }
}
