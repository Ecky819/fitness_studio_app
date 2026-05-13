import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Controller()
export class HealthController {
  constructor(private readonly prisma: PrismaService) {}

  // GET /health — liveness probe (container alive?)
  @Get('health')
  health() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }

  // GET /ready — readiness probe (DB reachable?)
  @Get('ready')
  async ready() {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { status: 'ready', db: 'ok', timestamp: new Date().toISOString() };
    } catch {
      return { status: 'not_ready', db: 'unreachable', timestamp: new Date().toISOString() };
    }
  }
}
