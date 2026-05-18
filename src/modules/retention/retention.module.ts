import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { RetentionController } from './retention.controller';
import { RetentionService } from './retention.service';
import { RetentionProcessor } from './retention.processor';
import { TenantContextService } from '../../common/tenant-context.service';
import { FeatureGuard } from '../../common/guards/feature.guard';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'retention' }),
    PrismaModule,
    AuthModule,
    NotificationsModule,
  ],
  controllers: [RetentionController],
  providers: [RetentionService, RetentionProcessor, TenantContextService, FeatureGuard],
  exports: [RetentionService],
})
export class RetentionModule {}
