import { Module } from '@nestjs/common';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { TenantContextService } from '../../common/tenant-context.service';
import { FeatureGuard } from '../../common/guards/feature.guard';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { redisProvider } from '../access/redis.provider';

@Module({
  imports: [PrismaModule, AuthModule, NotificationsModule],
  controllers: [AiController],
  providers: [AiService, TenantContextService, FeatureGuard, redisProvider],
  exports: [AiService],
})
export class AiModule {}
