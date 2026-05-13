import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { TenantContextService } from '../../common/tenant-context.service';
import { AnalyticsService } from './analytics.service';
import { AnalyticsDateRangeDto } from './dto/analytics-query.dto';

@Controller('admin/analytics')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.Admin, Role.Trainer)
export class AnalyticsController {
  constructor(
    private readonly analyticsService: AnalyticsService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  @Get('usage')
  getDailyUsage(@Query() query: AnalyticsDateRangeDto) {
    return this.analyticsService.getDailyUsage(this.tenantCtx.tenantId, query);
  }

  @Get('peaks')
  getPeakHours(@Query() query: AnalyticsDateRangeDto) {
    return this.analyticsService.getPeakHours(this.tenantCtx.tenantId, query);
  }

  @Get('revenue')
  getRevenue(@Query() query: AnalyticsDateRangeDto) {
    return this.analyticsService.getRevenue(this.tenantCtx.tenantId, query);
  }

  @Get('active-users')
  getActiveUsers() {
    return this.analyticsService.getActiveUsers(this.tenantCtx.tenantId);
  }
}
