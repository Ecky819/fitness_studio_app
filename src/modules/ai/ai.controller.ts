import { Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { FeatureGuard } from '../../common/guards/feature.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RequireFeature } from '../../common/decorators/require-feature.decorator';
import { Role } from '../../common/enums/role.enum';
import { FeatureFlag } from '../../common/constants/feature-flags';
import { TenantContextService } from '../../common/tenant-context.service';
import { AiService } from './ai.service';

@Controller('ai')
@UseGuards(JwtAuthGuard, RolesGuard, FeatureGuard)
@Roles(Role.Admin, Role.Trainer)
export class AiController {
  constructor(
    private readonly aiService: AiService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  // GET /api/ai/churn-risk?limit=50
  @Get('churn-risk')
  @RequireFeature(FeatureFlag.CHURN_RISK)
  getChurnRisk(@Query('limit') limit?: string) {
    return this.aiService.getChurnRiskForTenant(
      this.tenantCtx.tenantId,
      limit ? Number(limit) : 50,
    );
  }

  // POST /api/ai/churn-risk/refresh — trigger full recompute
  @Post('churn-risk/refresh')
  @Roles(Role.Admin)
  @RequireFeature(FeatureFlag.CHURN_RISK)
  refreshChurnRisk() {
    return this.aiService.computeAndCacheChurnRisk(this.tenantCtx.tenantId);
  }

  // GET /api/ai/anomalies — all anomaly types including tailgating and ghosts
  @Get('anomalies')
  @RequireFeature(FeatureFlag.ANOMALY_DETECTION)
  detectAnomalies() {
    return this.aiService.detectAnomalies(this.tenantCtx.tenantId);
  }

  // GET /api/ai/tailgating — detailed tailgating incidents (Admin only)
  @Get('tailgating')
  @Roles(Role.Admin)
  @RequireFeature(FeatureFlag.TAILGATING_DETECTION)
  detectTailgating() {
    return this.aiService.detectTailgating(this.tenantCtx.tenantId);
  }

  // GET /api/ai/ghost-members?limit=50 — members with active subscription but no visits
  @Get('ghost-members')
  @Roles(Role.Admin)
  @RequireFeature(FeatureFlag.TAILGATING_DETECTION)
  detectGhostMembers(@Query('limit') limit?: string) {
    return this.aiService.detectGhostMembers(
      this.tenantCtx.tenantId,
      limit ? Number(limit) : 50,
    );
  }
}
