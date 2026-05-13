import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtAuthGuard implements CanActivate {
    constructor(
        private readonly jwtService: JwtService,
        private readonly configService: ConfigService,
    ) {}

    async canActivate(context: ExecutionContext): Promise<boolean> {
        const request = context.switchToHttp().getRequest<any>();
        const authHeader = request.headers.authorization as string | undefined;

        if (!authHeader?.startsWith('Bearer ')) {
            throw new UnauthorizedException('Missing authorization header');
        }

        const token = authHeader.replace('Bearer ', '').trim();
        if (!token) throw new UnauthorizedException('Missing access token');

        try {
            const payload = await this.jwtService.verifyAsync(token, {
                secret: this.configService.getOrThrow<string>('JWT_ACCESS_SECRET'),
            });

            // Attach full JWT payload — downstream services read .sub, .role, .tenantId
            request.user = payload;
            return true;
        } catch {
            throw new UnauthorizedException('Invalid or expired access token');
        }
    }
}
