import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantContextService } from '../../common/tenant-context.service';
import { OccupancyService } from './occupancy.service';

@Controller('occupancy')
@UseGuards(JwtAuthGuard)
export class OccupancyController {
  constructor(
    private readonly occupancyService: OccupancyService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  // GET /api/occupancy/current — current live count
  @Get('current')
  getCurrent() {
    return this.occupancyService.getCurrentOccupancy(this.tenantCtx.tenantId);
  }

  // GET /api/occupancy/history?hours=24 — archived snapshots
  @Get('history')
  getHistory(@Query('hours') hours?: string) {
    return this.occupancyService.getOccupancyHistory(
      this.tenantCtx.tenantId,
      hours ? Number(hours) : 24,
    );
  }
}
