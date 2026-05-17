import { Body, Controller, Get, Headers, Param, ParseUUIDPipe, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { BillingService } from './billing.service';
import { UsageBillingService, EnableMeteredBillingDto } from './usage-billing.service';
import { CreateCheckoutSessionDto } from './dto/create-checkout-session.dto';
import { HardwareCheckoutDto } from './dto/hardware-checkout.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { TenantContextService } from '../../common/tenant-context.service';

@Controller('billing')
export class BillingController {
  constructor(
    private readonly billingService: BillingService,
    private readonly usageBilling: UsageBillingService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Post('create-checkout-session')
  createCheckoutSession(
    @Body() dto: CreateCheckoutSessionDto,
    @CurrentUser() user: any,
  ) {
    return this.billingService.createCheckoutSession(dto.planId, user.sub);
  }

  /**
   * POST /api/billing/hardware/checkout
   * Creates a one-time Stripe Checkout session for hardware purchase.
   * Uses mode: 'payment' (not subscription).
   */
  @UseGuards(JwtAuthGuard)
  @Post('hardware/checkout')
  createHardwareCheckout(
    @Body() dto: HardwareCheckoutDto,
    @CurrentUser() user: any,
  ) {
    return this.billingService.createHardwareCheckoutSession(
      user.sub,
      dto.stripePriceId,
      dto.quantity,
    );
  }

  @Post('webhook')
  handleWebhook(
    @Req() req: any,
    @Headers('stripe-signature') signature: string,
  ) {
    return this.billingService.handleWebhook(
      (req as any).rawBody || req.body,
      signature,
    );
  }

  /**
   * PATCH /api/billing/metered/:subscriptionId
   * Admin: link a Stripe subscription item (si_xxx) to a subscription for metered billing.
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.Admin)
  @Patch('metered/:subscriptionId')
  enableMetered(
    @Param('subscriptionId', ParseUUIDPipe) subscriptionId: string,
    @Body() dto: EnableMeteredBillingDto,
  ) {
    return this.usageBilling.enableMeteredBilling(
      subscriptionId,
      this.tenantCtx.tenantId,
      dto,
    );
  }

  /**
   * GET /api/billing/usage/current
   * Admin: preview the current month's billable access count.
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.Admin)
  @Get('usage/current')
  getCurrentUsage() {
    return this.usageBilling.getCurrentMonthUsage(this.tenantCtx.tenantId);
  }
}
