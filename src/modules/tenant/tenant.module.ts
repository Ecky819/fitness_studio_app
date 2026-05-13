import { Module } from '@nestjs/common';
import { TenantController } from './tenant.controller';
import { TenantService } from './tenant.service';
import { TenantContextService } from '../../common/tenant-context.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [TenantController],
  providers: [TenantService, TenantContextService],
  exports: [TenantService, TenantContextService],
})
export class TenantModule {}
