import { Module } from '@nestjs/common';
import { TierController, TierWebhookController } from './tier.controller';
import { TierService } from './tier.service';
import { TierGuard } from './tier.guard';
import { TenantContextService } from '../../common/tenant-context.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [TierController, TierWebhookController],
  providers: [TierService, TierGuard, TenantContextService],
  exports: [TierService, TierGuard],
})
export class TierModule {}
