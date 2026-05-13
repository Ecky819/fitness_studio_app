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
import { TenantService } from '../tenant/tenant.service';
import { CreateTenantDto } from '../tenant/dto/create-tenant.dto';
import {
  TenantQueryDto,
  UpdateTenantPlanDto,
  UpdateTenantStatusDto,
} from './dto/super-admin-query.dto';

/**
 * Super-Admin API — platform-level operations.
 * These routes skip tenant middleware (prefix /api/super-admin).
 * Requires SUPER_ADMIN role; regular gym admins cannot access this.
 */
@Controller('super-admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.SuperAdmin)
export class SuperAdminController {
  constructor(private readonly tenantService: TenantService) {}

  // GET  /api/super-admin/platform-stats
  @Get('platform-stats')
  getPlatformStats() {
    return this.tenantService.getPlatformStats();
  }

  // GET  /api/super-admin/tenants
  @Get('tenants')
  listTenants(@Query() query: TenantQueryDto) {
    return this.tenantService.findAll({
      page: query.page ?? 1,
      limit: query.limit ?? 20,
      search: query.search,
    });
  }

  // POST /api/super-admin/tenants
  @Post('tenants')
  createTenant(@Body() dto: CreateTenantDto) {
    return this.tenantService.create(dto);
  }

  // GET  /api/super-admin/tenants/:id
  @Get('tenants/:id')
  getTenant(@Param('id', ParseUUIDPipe) id: string) {
    return this.tenantService.findOne(id);
  }

  // PATCH /api/super-admin/tenants/:id/plan
  @Patch('tenants/:id/plan')
  updatePlan(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTenantPlanDto,
  ) {
    return this.tenantService.updatePlan(id, dto.plan);
  }

  // PATCH /api/super-admin/tenants/:id/status
  @Patch('tenants/:id/status')
  updateStatus(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateTenantStatusDto,
  ) {
    return this.tenantService.updateStatus(id, dto.status);
  }
}
