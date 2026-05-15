import { Module } from '@nestjs/common';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { TenantContextService } from '../../common/tenant-context.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { redisProvider } from '../access/redis.provider';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [AiController],
  providers: [AiService, TenantContextService, redisProvider],
  exports: [AiService],
})
export class AiModule {}
