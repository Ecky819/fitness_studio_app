import { Body, Controller, Headers, Post, Req, UseGuards } from '@nestjs/common';
import { BillingService } from './billing.service';
import { CreateCheckoutSessionDto } from './dto/create-checkout-session.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('billing')
export class BillingController {
    constructor(private readonly billingService: BillingService) { }

    @UseGuards(JwtAuthGuard)
    @Post('create-checkout-session')
    async createCheckoutSession(@Body() dto: CreateCheckoutSessionDto, @CurrentUser() user: any) {
        return this.billingService.createCheckoutSession(dto.planId, user.sub);
    }

    @Post('webhook')
    async handleWebhook(@Req() req: any, @Headers('stripe-signature') signature: string) {
        return this.billingService.handleWebhook((req as any).rawBody || req.body, signature);
    }
}
