import { Module, OnModuleInit } from '@nestjs/common';
import { OccupancyController } from './occupancy.controller';
import { OccupancyConsumer } from './occupancy.consumer';
import { OccupancyGateway } from './occupancy.gateway';
import { OccupancyService } from './occupancy.service';
import { TenantContextService } from '../../common/tenant-context.service';
import { MqttModule } from '../mqtt/mqtt.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [PrismaModule, AuthModule, MqttModule],
  controllers: [OccupancyController],
  providers: [OccupancyGateway, OccupancyService, OccupancyConsumer, TenantContextService],
  exports: [OccupancyService],
})
export class OccupancyModule implements OnModuleInit {
  constructor(
    private readonly occupancyService: OccupancyService,
    private readonly gateway: OccupancyGateway,
  ) {}

  // Break circular dep between OccupancyService ↔ OccupancyGateway
  onModuleInit() {
    this.occupancyService.setGateway(this.gateway);
  }
}
