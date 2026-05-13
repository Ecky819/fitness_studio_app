import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { TenantContextService } from '../../common/tenant-context.service';
import { TenantService } from './tenant.service';
import { UpdateTenantConfigDto } from './dto/update-tenant-config.dto';

@Controller('tenant')
export class TenantController {
  constructor(
    private readonly tenantService: TenantService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  // GET /api/tenant/config — public endpoint (no auth required)
  // Used by Flutter on startup to load white-label config
  @Get('config')
  getConfig() {
    return this.tenantService.getPublicConfig(this.tenantCtx.tenantId);
  }

  // PATCH /api/tenant/config — Admin only, updates white-label settings
  @Patch('config')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(Role.Admin)
  updateConfig(@Body() dto: UpdateTenantConfigDto) {
    return this.tenantService.updateConfig(this.tenantCtx.tenantId, dto);
  }
}
