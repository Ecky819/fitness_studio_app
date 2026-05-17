import { Body, Controller, Get, Headers, Post, Query, UnauthorizedException, UseGuards } from '@nestjs/common';
import { IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { ConfigService } from '@nestjs/config';
import { createHmac } from 'crypto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { TenantContextService } from '../../common/tenant-context.service';
import { OccupancyService } from './occupancy.service';

class CameraEventDto {
  @IsString()
  cameraId: string;

  @IsNumber()
  @Min(0)
  count: number;

  @IsOptional()
  @IsNumber()
  confidence?: number;
}

@Controller('occupancy')
@UseGuards(JwtAuthGuard)
export class OccupancyController {
  constructor(
    private readonly occupancyService: OccupancyService,
    private readonly tenantCtx: TenantContextService,
    private readonly config: ConfigService,
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

  // GET /api/occupancy/heatmap?days=28 — 7×24 avg-occupancy matrix
  @Get('heatmap')
  getHeatmap(@Query('days') days?: string) {
    return this.occupancyService.getHeatmap(
      this.tenantCtx.tenantId,
      days ? Number(days) : 28,
    );
  }

  /**
   * POST /api/occupancy/camera
   * HTTP webhook for AI edge devices that process RTSP streams.
   * Authenticates via HMAC-SHA256 signature in X-Camera-Signature header
   * (signed with CAMERA_WEBHOOK_SECRET env var).
   * Use this as fallback when the camera cannot reach the MQTT broker.
   */
  @Post('camera')
  async cameraEvent(
    @Body() dto: CameraEventDto,
    @Headers('x-camera-signature') sig: string,
  ) {
    this.verifySignature(dto, sig);
    await this.occupancyService.recordCameraCount(
      this.tenantCtx.tenantId,
      dto.cameraId,
      dto.count,
    );
    return { accepted: true };
  }

  private verifySignature(payload: unknown, signature: string) {
    const secret = this.config.get<string>('CAMERA_WEBHOOK_SECRET');
    if (!secret) return; // opt-in; skip if not configured

    const expected = createHmac('sha256', secret)
      .update(JSON.stringify(payload))
      .digest('hex');

    if (expected !== signature) {
      throw new UnauthorizedException('Invalid camera webhook signature');
    }
  }
}
