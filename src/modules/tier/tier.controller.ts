import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  RawBodyRequest,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { TenantContextService } from '../../common/tenant-context.service';
import { TierService } from './tier.service';
import { IsEnum, IsString, IsUrl } from 'class-validator';
import { SaasPlan } from '@prisma/client';

class UpgradeDto {
  @IsEnum(SaasPlan)
  newPlan!: SaasPlan;

  @IsString() @IsUrl()
  frontendUrl!: string;
}

class ChangePlanDto {
  @IsEnum(SaasPlan)
  newPlan!: SaasPlan;
}

@Controller('tier')
@UseGuards(JwtAuthGuard, RolesGuard)
export class TierController {
  constructor(
    private readonly tierService: TierService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  /**
   * GET /api/tier/usage
   * Returns current plan, limits, and actual usage for the tenant.
   */
  @Get('usage')
  @Roles(Role.Admin)
  getUsage() {
    return this.tierService.getCurrentLimits(this.tenantCtx.tenantId);
  }

  /**
   * POST /api/tier/upgrade
   * Creates a Stripe Checkout Session to upgrade the tenant's SaaS plan.
   * Returns the checkout URL.
   */
  @Post('upgrade')
  @Roles(Role.Admin)
  upgrade(@Body() dto: UpgradeDto) {
    return this.tierService.createUpgradeCheckoutSession(
      this.tenantCtx.tenantId,
      dto.newPlan,
      dto.frontendUrl,
    );
  }

  /**
   * POST /api/tier/plan — super-admin only: directly set a tenant's plan.
   * Used for manual overrides (custom deals, trial extensions, downgrades).
   */
  @Post('plan')
  @Roles(Role.SuperAdmin)
  @HttpCode(HttpStatus.OK)
  changePlan(
    @Body() dto: ChangePlanDto,
    @Query('tenantId') tenantId?: string,
  ) {
    const target = tenantId ?? this.tenantCtx.tenantId;
    return this.tierService.applyPlanChange(target, dto.newPlan);
  }

}

/**
 * Separate unguarded controller for the Stripe SaaS billing webhook.
 * Raw body access is required for signature validation — no JWT guard.
 * Route is excluded from TenantMiddleware in app.module.ts.
 */
@Controller('tier')
export class TierWebhookController {
  constructor(private readonly tierService: TierService) {}

  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  async stripeWebhook(
    @Req() req: RawBodyRequest<Request>,
    @Headers('stripe-signature') sig: string,
  ) {
    await this.tierService.handleStripeWebhook(req.rawBody!, sig);
    return { received: true };
  }
}
