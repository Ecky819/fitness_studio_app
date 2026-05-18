import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { SaasPlan } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TenantContextService } from '../../common/tenant-context.service';
import { REQUIRE_PLAN_KEY } from './decorators/require-plan.decorator';
import { isPlanAtLeast } from './tier.constants';

@Injectable()
export class TierGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPlan = this.reflector.getAllAndOverride<SaasPlan>(REQUIRE_PLAN_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredPlan) return true;

    const request = context.switchToHttp().getRequest();
    if (request.user?.role === 'SUPER_ADMIN') return true;

    const tenantId = this.tenantCtx.tenantIdOrNull;
    if (!tenantId) throw new ForbiddenException('Tenant not identified');

    const tenant = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { plan: true, status: true },
    });

    if (!tenant) throw new ForbiddenException('Tenant not found');
    if (tenant.status === 'SUSPENDED' || tenant.status === 'CANCELLED') {
      throw new ForbiddenException(`Tenant account is ${tenant.status.toLowerCase()}`);
    }

    if (!isPlanAtLeast(tenant.plan, requiredPlan)) {
      throw new ForbiddenException(
        `This feature requires the ${requiredPlan} plan or higher. Current plan: ${tenant.plan}`,
      );
    }

    return true;
  }
}
