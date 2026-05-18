import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { EdgeController } from './edge.controller';
import { EdgeService } from './edge.service';
import { EdgeProcessor } from './edge.processor';
import { TenantContextService } from '../../common/tenant-context.service';
import { FeatureGuard } from '../../common/guards/feature.guard';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'edge-sync' }),
    PrismaModule,
    AuthModule,
  ],
  controllers: [EdgeController],
  providers: [EdgeService, EdgeProcessor, TenantContextService, FeatureGuard],
  exports: [EdgeService],
})
export class EdgeModule {}
