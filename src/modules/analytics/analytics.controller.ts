import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { Role } from '../../common/enums/role.enum';
import { AnalyticsService } from './analytics.service';
import { AnalyticsDateRangeDto } from './dto/analytics-query.dto';

// All analytics endpoints require a valid JWT + Admin or Trainer role.
@Controller('admin/analytics')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(Role.Admin, Role.Trainer)
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  // GET /admin/analytics/usage?dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD
  @Get('usage')
  getDailyUsage(@Query() query: AnalyticsDateRangeDto) {
    return this.analyticsService.getDailyUsage(query);
  }

  // GET /admin/analytics/peaks?dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD
  @Get('peaks')
  getPeakHours(@Query() query: AnalyticsDateRangeDto) {
    return this.analyticsService.getPeakHours(query);
  }

  // GET /admin/analytics/revenue?dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD
  @Get('revenue')
  getRevenue(@Query() query: AnalyticsDateRangeDto) {
    return this.analyticsService.getRevenue(query);
  }

  // GET /admin/analytics/active-users
  @Get('active-users')
  getActiveUsers() {
    return this.analyticsService.getActiveUsers();
  }
}
