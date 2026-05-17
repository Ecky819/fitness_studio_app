import { Module } from '@nestjs/common';
import { DeviceProvisioningController } from './device-provisioning.controller';
import { DeviceProvisioningService } from './device-provisioning.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [DeviceProvisioningController],
  providers: [DeviceProvisioningService],
})
export class DeviceProvisioningModule {}
