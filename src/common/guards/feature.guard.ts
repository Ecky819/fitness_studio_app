import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
import { REQUIRE_FEATURE_KEY } from '../decorators/require-feature.decorator';
import { FeatureFlagKey } from '../constants/feature-flags';

/**
 * Guards a route by checking whether the current tenant has a specific
 * feature enabled in TenantConfig.features.
 *
 * Usage:
 *   @UseGuards(JwtAuthGuard, RolesGuard, FeatureGuard)
 *   @RequireFeature(FeatureFlag.CHURN_RISK)
 *   @Get('churn-risk')
 *   getChurnRisk() { … }
 *
 * SUPER_ADMIN role bypasses all feature checks.
 */
@Injectable()
export class FeatureGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const flag = this.reflector.getAllAndOverride<FeatureFlagKey | undefined>(
      REQUIRE_FEATURE_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (!flag) return true; // no feature requirement on this route

    const req = context.switchToHttp().getRequest<{ user?: { role?: string; tenantId?: string } }>();
    const user = req.user;

    // SUPER_ADMIN bypasses all feature gates
    if (user?.role === 'SUPER_ADMIN') return true;

    const tenantId = user?.tenantId;
    if (!tenantId) throw new ForbiddenException('No tenant context');

    const config = await this.prisma.tenantConfig.findUnique({
      where: { tenantId },
      select: { features: true },
    });

    const features = (config?.features as Record<string, unknown>) ?? {};

    if (!features[flag]) {
      throw new ForbiddenException(
        `Feature "${flag}" is not enabled for your plan. Please upgrade to access this feature.`,
      );
    }

    return true;
  }
}
