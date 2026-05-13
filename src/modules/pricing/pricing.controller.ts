import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { TenantContextService } from '../../common/tenant-context.service';
import { PricingService } from './pricing.service';
import { CreatePricingRuleDto } from './dto/pricing-rule.dto';

@Controller('pricing')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PricingController {
  constructor(
    private readonly pricingService: PricingService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  // GET /api/pricing/current?planId=... — called before checkout
  @Get('current')
  getCurrent(@Query('planId') planId: string) {
    return this.pricingService.getCurrentModifier(this.tenantCtx.tenantId, planId);
  }

  // GET /api/pricing/rules — admin view all rules
  @Get('rules')
  @Roles(Role.Admin)
  listRules() {
    return this.pricingService.listRules(this.tenantCtx.tenantId);
  }

  // POST /api/pricing/rules
  @Post('rules')
  @Roles(Role.Admin)
  createRule(@Body() dto: CreatePricingRuleDto) {
    return this.pricingService.createRule(this.tenantCtx.tenantId, dto);
  }

  // PATCH /api/pricing/rules/:id/toggle
  @Patch('rules/:id/toggle')
  @Roles(Role.Admin)
  toggleRule(@Param('id', ParseUUIDPipe) id: string) {
    return this.pricingService.toggleRule(this.tenantCtx.tenantId, id);
  }

  // DELETE /api/pricing/rules/:id
  @Delete('rules/:id')
  @Roles(Role.Admin)
  deleteRule(@Param('id', ParseUUIDPipe) id: string) {
    return this.pricingService.deleteRule(this.tenantCtx.tenantId, id);
  }
}
