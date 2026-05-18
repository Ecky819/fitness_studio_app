import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
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
import { RetentionService } from './retention.service';
import {
  CreateWorkflowDto,
  UpdateWorkflowDto,
  ListExecutionsQueryDto,
} from './dto/retention.dto';

@Controller('retention')
@UseGuards(JwtAuthGuard, RolesGuard, FeatureGuard)
@Roles(Role.Admin)
@RequireFeature(FeatureFlag.RETENTION_WORKFLOWS)
export class RetentionController {
  constructor(
    private readonly retentionService: RetentionService,
    private readonly tenantCtx: TenantContextService,
  ) {}

  // ── Workflow CRUD ─────────────────────────────────────────────────────────

  // POST /api/retention/workflows
  @Post('workflows')
  createWorkflow(@Body() dto: CreateWorkflowDto) {
    return this.retentionService.createWorkflow(this.tenantCtx.tenantId, dto);
  }

  // GET /api/retention/workflows
  @Get('workflows')
  listWorkflows() {
    return this.retentionService.listWorkflows(this.tenantCtx.tenantId);
  }

  // GET /api/retention/workflows/:id
  @Get('workflows/:id')
  getWorkflow(@Param('id') id: string) {
    return this.retentionService.getWorkflow(this.tenantCtx.tenantId, id);
  }

  // PATCH /api/retention/workflows/:id
  @Patch('workflows/:id')
  updateWorkflow(@Param('id') id: string, @Body() dto: UpdateWorkflowDto) {
    return this.retentionService.updateWorkflow(this.tenantCtx.tenantId, id, dto);
  }

  // DELETE /api/retention/workflows/:id
  @Delete('workflows/:id')
  deleteWorkflow(@Param('id') id: string) {
    return this.retentionService.deleteWorkflow(this.tenantCtx.tenantId, id);
  }

  // ── Trigger ───────────────────────────────────────────────────────────────

  // POST /api/retention/evaluate — manually trigger evaluation for this tenant
  @Post('evaluate')
  evaluate() {
    return this.retentionService.evaluateWorkflowsForTenant(this.tenantCtx.tenantId);
  }

  // ── Execution History ─────────────────────────────────────────────────────

  // GET /api/retention/executions?workflowId=&userId=&status=&limit=
  @Get('executions')
  listExecutions(@Query() query: ListExecutionsQueryDto) {
    return this.retentionService.listExecutions(this.tenantCtx.tenantId, query);
  }

  // GET /api/retention/workflows/:id/stats
  @Get('workflows/:id/stats')
  getStats(@Param('id') id: string) {
    return this.retentionService.getWorkflowStats(this.tenantCtx.tenantId, id);
  }
}
