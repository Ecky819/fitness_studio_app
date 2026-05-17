import { Module } from '@nestjs/common';
import { HardwareService } from './hardware.service';
import { BleSecureAdapter } from './adapters/ble-secure.adapter';
import { KisiAdapter } from './adapters/kisi.adapter';
import { BrivoAdapter } from './adapters/brivo.adapter';
import { TapkeyAdapter } from './adapters/tapkey.adapter';
import { PrismaModule } from '../../prisma/prisma.module';
import { MqttModule } from '../mqtt/mqtt.module';

@Module({
  imports: [PrismaModule, MqttModule],
  providers: [
    HardwareService,
    BleSecureAdapter,
    KisiAdapter,
    BrivoAdapter,
    TapkeyAdapter,
  ],
  exports: [HardwareService],
})
export class AccessHardwareModule {}
