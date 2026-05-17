import { Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { DeviceHandshakeDto } from './dto/handshake.dto';

/**
 * Handles the one-time handshake a device performs after first boot.
 *
 * Flow:
 *   1. Admin calls POST /admin/devices/provision → gets a provisioningToken
 *   2. Token is flashed into the device firmware (or QR-scanned during install)
 *   3. On first boot the device calls POST /devices/handshake with the token
 *   4. Token is consumed (cleared), device is marked provisioned
 *   5. Device is now trusted and can publish MQTT events
 */
@Injectable()
export class DeviceProvisioningService {
  constructor(private readonly prisma: PrismaService) {}

  async handshake(dto: DeviceHandshakeDto) {
    const device = await this.prisma.device.findUnique({
      where: { provisioningToken: dto.provisioningToken },
    });

    if (!device) {
      throw new UnauthorizedException('Invalid or already used provisioning token');
    }

    if (device.doorId !== dto.doorId) {
      throw new UnauthorizedException('doorId does not match provisioning token');
    }

    const updated = await this.prisma.device.update({
      where: { id: device.id },
      data: {
        provisioningToken: null,    // consume token — one-time use
        provisionedAt: new Date(),
        isOnline: true,
        lastSeenAt: new Date(),
        ...(dto.firmwareVersion ? { firmwareVersion: dto.firmwareVersion } : {}),
      },
      select: {
        id: true,
        tenantId: true,
        doorId: true,
        name: true,
        location: true,
        type: true,
        firmwareVersion: true,
        provisionedAt: true,
      },
    });

    return {
      device: updated,
      mqttTopicPrefix: `gym/${updated.tenantId}/door/${updated.doorId}`,
      message: 'Device provisioned successfully',
    };
  }
}
