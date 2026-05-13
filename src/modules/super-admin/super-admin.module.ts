import { Module } from '@nestjs/common';
import { SuperAdminController } from './super-admin.controller';
import { TenantModule } from '../tenant/tenant.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [TenantModule, AuthModule],
  controllers: [SuperAdminController],
})
export class SuperAdminModule {}
