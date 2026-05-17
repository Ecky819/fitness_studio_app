import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { BillingController } from './billing.controller';
import { BillingService } from './billing.service';
import { UsageBillingService } from './usage-billing.service';
import { TenantContextService } from '../../common/tenant-context.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { InvoiceModule } from '../invoice/invoice.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [ConfigModule, PrismaModule, AuthModule, InvoiceModule, NotificationsModule],
  controllers: [BillingController],
  providers: [BillingService, UsageBillingService, TenantContextService],
  exports: [BillingService, UsageBillingService],
})
export class BillingModule {}
