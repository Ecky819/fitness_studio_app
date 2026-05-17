import { Module } from '@nestjs/common';
import { PricingController } from './pricing.controller';
import { PricingService } from './pricing.service';
import { TenantContextService } from '../../common/tenant-context.service';
import { FeatureGuard } from '../../common/guards/feature.guard';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [PricingController],
  providers: [PricingService, TenantContextService, FeatureGuard],
  exports: [PricingService],
})
export class PricingModule {}
