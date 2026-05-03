import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { AdminService } from './admin.service';
import { AdminLogsQueryDto, AdminUsersQueryDto } from './dto/admin-query.dto';

// All endpoints in this controller require a valid JWT + Admin role.
// Trainer-accessible endpoints override @Roles at the method level.
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.Admin)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  // GET /admin/stats — Admin only
  @Get('stats')
  getStats() {
    return this.adminService.getStats();
  }

  // GET /admin/users — Admin only
  @Get('users')
  getUsers(@Query() query: AdminUsersQueryDto) {
    return this.adminService.getUsers(query);
  }

  // PATCH /admin/users/:id/block — Admin only (toggle block/unblock)
  @Patch('users/:id/block')
  blockUser(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.toggleBlock(id);
  }

  // GET /admin/devices — Trainer + Admin can view devices
  @Get('devices')
  @Roles(Role.Admin, Role.Trainer)
  getDevices() {
    return this.adminService.getDevices();
  }

  // GET /admin/logs — Trainer + Admin can view logs
  @Get('logs')
  @Roles(Role.Admin, Role.Trainer)
  getLogs(@Query() query: AdminLogsQueryDto) {
    return this.adminService.getLogs(query);
  }
}
