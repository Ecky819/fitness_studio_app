import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { FeatureGuard } from '../../common/guards/feature.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { RequireFeature } from '../../common/decorators/require-feature.decorator';
import { Role } from '../../common/enums/role.enum';
import { FeatureFlag } from '../../common/constants/feature-flags';
import { TenantContextService } from '../../common/tenant-context.service';
import { EdgeService } from './edge.service';
import { BatchSyncDto, EdgeSyncStatusQueryDto } from './dto/edge.dto';

@Controller('edge')
@UseGuards(JwtAuthGuard, RolesGuard, FeatureGuard)
@RequireFeature(FeatureFlag.EDGE_SYNC)
export class EdgeController {
  constructor(
    private readonly edgeService: EdgeService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  /**
   * POST /api/edge/sync
   * Called by edge devices (door controllers) after regaining connectivity.
   * Accepts a batch of buffered offline events and queues them for replay.
   * Accessible by any authenticated device user.
   */
  @Post('sync')
  @HttpCode(HttpStatus.ACCEPTED)
  @Roles(Role.Admin, Role.User)
  batchSync(@Req() req: any, @Body() dto: BatchSyncDto) {
    const deviceId: string = req.user?.deviceId ?? req.user?.sub;
    return this.edgeService.batchSync(deviceId, this.tenantCtx.tenantId, dto);
  }

  /**
   * GET /api/edge/sync/status?deviceId=xxx
   * Returns pending/completed/failed event counts for a device or the whole tenant.
   */
  @Get('sync/status')
  @Roles(Role.Admin, Role.Trainer)
  getSyncStatus(@Query() query: EdgeSyncStatusQueryDto) {
    return this.edgeService.getSyncStatus(this.tenantCtx.tenantId, query.deviceId);
  }

  /**
   * POST /api/edge/sync/retry
   * Re-queues all FAILED events for a device (or the whole tenant). Admin only.
   */
  @Post('sync/retry')
  @Roles(Role.Admin)
  @HttpCode(HttpStatus.ACCEPTED)
  retryFailed(@Query() query: EdgeSyncStatusQueryDto) {
    return this.edgeService.retryFailed(this.tenantCtx.tenantId, query.deviceId);
  }
}
