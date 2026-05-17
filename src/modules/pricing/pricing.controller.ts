import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { FeatureGuard } from '../../common/guards/feature.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RequireFeature } from '../../common/decorators/require-feature.decorator';
import { Role } from '../../common/enums/role.enum';
import { FeatureFlag } from '../../common/constants/feature-flags';
import { TenantContextService } from '../../common/tenant-context.service';
import { PricingService } from './pricing.service';
import { CreatePricingRuleDto } from './dto/pricing-rule.dto';

@Controller('pricing')
@UseGuards(JwtAuthGuard, RolesGuard, FeatureGuard)
export class PricingController {
  constructor(
    private readonly pricingService: PricingService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  // GET /api/pricing/current?planId=... — price modifier before checkout (no feature gate — public to members)
  @Get('current')
  getCurrent(@Query('planId') planId: string) {
    return this.pricingService.getCurrentModifier(this.tenantCtx.tenantId, planId);
  }

  // Admin-only write endpoints require DYNAMIC_PRICING feature flag
  @Get('rules')
  @Roles(Role.Admin)
  @RequireFeature(FeatureFlag.DYNAMIC_PRICING)
  listRules() {
    return this.pricingService.listRules(this.tenantCtx.tenantId);
  }

  @Post('rules')
  @Roles(Role.Admin)
  @RequireFeature(FeatureFlag.DYNAMIC_PRICING)
  createRule(@Body() dto: CreatePricingRuleDto) {
    return this.pricingService.createRule(this.tenantCtx.tenantId, dto);
  }

  @Patch('rules/:id/toggle')
  @Roles(Role.Admin)
  @RequireFeature(FeatureFlag.DYNAMIC_PRICING)
  toggleRule(@Param('id', ParseUUIDPipe) id: string) {
    return this.pricingService.toggleRule(this.tenantCtx.tenantId, id);
  }

  @Delete('rules/:id')
  @Roles(Role.Admin)
  @RequireFeature(FeatureFlag.DYNAMIC_PRICING)
  deleteRule(@Param('id', ParseUUIDPipe) id: string) {
    return this.pricingService.deleteRule(this.tenantCtx.tenantId, id);
  }
}
