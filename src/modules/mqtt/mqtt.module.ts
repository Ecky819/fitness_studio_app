import { Module } from '@nestjs/common';
import { MqttService } from './mqtt.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  providers: [MqttService],
  exports: [MqttService],
})
export class MqttModule {}
