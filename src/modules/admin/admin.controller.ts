import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { TenantContextService } from '../../common/tenant-context.service';
import { AdminService } from './admin.service';
import { AdminLogsQueryDto, AdminUsersQueryDto, FirmwareUpdateDto, ProvisionDeviceDto } from './dto/admin-query.dto';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.Admin)
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  @Get('stats')
  getStats() {
    return this.adminService.getStats(this.tenantCtx.tenantId);
  }

  @Get('users')
  getUsers(@Query() query: AdminUsersQueryDto) {
    return this.adminService.getUsers(this.tenantCtx.tenantId, query);
  }

  @Patch('users/:id/block')
  blockUser(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.toggleBlock(id, this.tenantCtx.tenantId);
  }

  @Get('devices')
  @Roles(Role.Admin, Role.Trainer)
  getDevices() {
    return this.adminService.getDevices(this.tenantCtx.tenantId);
  }

  @Get('logs')
  @Roles(Role.Admin, Role.Trainer)
  getLogs(@Query() query: AdminLogsQueryDto) {
    return this.adminService.getLogs(this.tenantCtx.tenantId, query);
  }

  // POST /admin/devices/provision — register a new device and return a one-time provisioning token
  @Post('devices/provision')
  provisionDevice(@Body() dto: ProvisionDeviceDto) {
    return this.adminService.provisionDevice(this.tenantCtx.tenantId, dto);
  }

  // PATCH /admin/devices/:id/firmware — push an OTA update command via MQTT
  @Patch('devices/:id/firmware')
  pushFirmware(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: FirmwareUpdateDto,
  ) {
    return this.adminService.pushFirmwareUpdate(this.tenantCtx.tenantId, id, dto);
  }
}
