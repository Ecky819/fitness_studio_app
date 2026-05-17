import { Body, Controller, Post } from '@nestjs/common';
import { DeviceProvisioningService } from './device-provisioning.service';
import { DeviceHandshakeDto } from './dto/handshake.dto';

/**
 * Public endpoint — no JWT required.
 * The device authenticates via a single-use provisioning token.
 * This route is excluded from the TenantMiddleware (no X-Tenant-Slug needed).
 */
@Controller('devices')
export class DeviceProvisioningController {
  constructor(private readonly service: DeviceProvisioningService) {}

  // POST /api/devices/handshake
  @Post('handshake')
  handshake(@Body() dto: DeviceHandshakeDto) {
    return this.service.handshake(dto);
  }
}
