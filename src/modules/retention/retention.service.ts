import {
  Injectable,
  Logger,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { Prisma } from '@prisma/client';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  CreateWorkflowDto,
  UpdateWorkflowDto,
  ListExecutionsQueryDto,
  RetentionStepDto,
  RetentionStepType,
  RetentionTriggerType,
} from './dto/retention.dto';

export interface RetentionJobData {
  executionId: string;
}

@Injectable()
export class RetentionService {
  private readonly logger = new Logger(RetentionService.name);
  private readonly stripe: Stripe;

  // Redis throttle window: don't re-trigger the same workflow for the same
  // user within 7 days to avoid notification spam.
  private readonly THROTTLE_TTL_SECONDS = 7 * 24 * 60 * 60;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly config: ConfigService,
    @InjectQueue('retention') private readonly retentionQueue: Queue,
  ) {
    this.stripe = new Stripe(
      this.config.getOrThrow<string>('STRIPE_SECRET_KEY'),
      { apiVersion: '2022-11-15' },
    );
  }

  // ── Workflow CRUD ─────────────────────────────────────────────────────────

  async createWorkflow(tenantId: string, dto: CreateWorkflowDto) {
    return this.prisma.retentionWorkflow.create({
      data: {
        tenantId,
        name: dto.name,
        description: dto.description,
        triggerType: dto.triggerType as any,
        minChurnScore: dto.minChurnScore,
        minDaysInactive: dto.minDaysInactive,
        daysBeforeExpiry: dto.daysBeforeExpiry,
        steps: dto.steps as unknown as Prisma.InputJsonValue,
      },
    });
  }

  async listWorkflows(tenantId: string) {
    return this.prisma.retentionWorkflow.findMany({
      where: { tenantId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getWorkflow(tenantId: string, workflowId: string) {
    const wf = await this.prisma.retentionWorkflow.findFirst({
      where: { id: workflowId, tenantId },
    });
    if (!wf) throw new NotFoundException('Workflow not found');
    return wf;
  }

  async updateWorkflow(tenantId: string, workflowId: string, dto: UpdateWorkflowDto) {
    await this.getWorkflow(tenantId, workflowId);
    return this.prisma.retentionWorkflow.update({
      where: { id: workflowId },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.description !== undefined && { description: dto.description }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
        ...(dto.triggerType !== undefined && { triggerType: dto.triggerType as any }),
        ...(dto.minChurnScore !== undefined && { minChurnScore: dto.minChurnScore }),
        ...(dto.minDaysInactive !== undefined && { minDaysInactive: dto.minDaysInactive }),
        ...(dto.daysBeforeExpiry !== undefined && { daysBeforeExpiry: dto.daysBeforeExpiry }),
        ...(dto.steps !== undefined && { steps: dto.steps as unknown as Prisma.InputJsonValue }),
      },
    });
  }

  async deleteWorkflow(tenantId: string, workflowId: string) {
    await this.getWorkflow(tenantId, workflowId);
    await this.prisma.retentionExecution.deleteMany({ where: { workflowId } });
    await this.prisma.retentionWorkflow.delete({ where: { id: workflowId } });
  }

  // ── Trigger Evaluation ────────────────────────────────────────────────────

  /**
   * Scheduled every 6 hours to check all active workflows across all tenants.
   * For each workflow, evaluates eligible users and queues executions.
   */
  @Cron(CronExpression.EVERY_6_HOURS)
  async evaluateAllTenants() {
    this.logger.log('Evaluating retention workflows across all tenants');
    const tenants = await this.prisma.tenant.findMany({
      where: { status: 'ACTIVE' },
      select: { id: true },
    });
    for (const { id } of tenants) {
      await this.evaluateWorkflowsForTenant(id);
    }
  }

  async evaluateWorkflowsForTenant(tenantId: string): Promise<number> {
    const workflows = await this.prisma.retentionWorkflow.findMany({
      where: { tenantId, isActive: true },
    });

    let triggered = 0;
    for (const workflow of workflows) {
      triggered += await this.evaluateWorkflow(workflow);
    }
    this.logger.log(`[${tenantId}] Triggered ${triggered} retention executions`);
    return triggered;
  }

  private async evaluateWorkflow(workflow: any): Promise<number> {
    const { tenantId, id: workflowId, triggerType } = workflow;
    const now = new Date();
    let triggered = 0;

    switch (triggerType as RetentionTriggerType) {
      case RetentionTriggerType.CHURN_SCORE_THRESHOLD: {
        const threshold = workflow.minChurnScore ?? 60;
        const insights = await this.prisma.aiInsight.findMany({
          where: { tenantId, churnScore: { gte: threshold } },
          select: { userId: true, churnScore: true, riskLevel: true, recommendation: true },
        });
        for (const insight of insights) {
          const throttled = await this.isThrottled(workflowId, insight.userId);
          if (throttled) continue;
          await this.createExecution(workflowId, insight.userId, tenantId, {
            churnScore: insight.churnScore,
            riskLevel: insight.riskLevel,
            recommendation: insight.recommendation,
            triggeredAt: now.toISOString(),
          });
          triggered++;
        }
        break;
      }

      case RetentionTriggerType.DAYS_INACTIVE: {
        const cutoff = new Date(Date.now() - (workflow.minDaysInactive ?? 14) * 86_400_000);
        const users = await this.prisma.$queryRaw<{ id: string; lastVisit: Date | null }[]>`
          SELECT u.id, MAX(ae."createdAt") AS "lastVisit"
          FROM "User" u
          LEFT JOIN "AccessEvent" ae ON ae."userId" = u.id AND ae.status::text = 'GRANTED'
          INNER JOIN "Subscription" s ON s."userId" = u.id AND s.status::text = 'ACTIVE'
          WHERE u."tenantId" = ${tenantId} AND u."isBlocked" = false
          GROUP BY u.id
          HAVING MAX(ae."createdAt") IS NULL OR MAX(ae."createdAt") < ${cutoff}
          LIMIT 200
        `;
        for (const user of users) {
          const throttled = await this.isThrottled(workflowId, user.id);
          if (throttled) continue;
          const daysSince = user.lastVisit
            ? Math.floor((now.getTime() - user.lastVisit.getTime()) / 86_400_000)
            : null;
          await this.createExecution(workflowId, user.id, tenantId, {
            daysSinceLastVisit: daysSince,
            neverVisited: user.lastVisit === null,
            triggeredAt: now.toISOString(),
          });
          triggered++;
        }
        break;
      }

      case RetentionTriggerType.SUBSCRIPTION_EXPIRING: {
        const daysAhead = workflow.daysBeforeExpiry ?? 7;
        const windowStart = now;
        const windowEnd = new Date(Date.now() + daysAhead * 86_400_000);
        const subs = await this.prisma.subscription.findMany({
          where: {
            user: { tenantId },
            status: 'ACTIVE',
            validUntil: { gte: windowStart, lte: windowEnd },
          },
          select: { userId: true, validUntil: true },
        });
        for (const sub of subs) {
          const throttled = await this.isThrottled(workflowId, sub.userId);
          if (throttled) continue;
          const daysLeft = Math.floor((sub.validUntil.getTime() - now.getTime()) / 86_400_000);
          await this.createExecution(workflowId, sub.userId, tenantId, {
            daysUntilExpiry: daysLeft,
            expiresAt: sub.validUntil.toISOString(),
            triggeredAt: now.toISOString(),
          });
          triggered++;
        }
        break;
      }
    }

    return triggered;
  }

  // ── Execution Management ──────────────────────────────────────────────────

  private async createExecution(
    workflowId: string,
    userId: string,
    tenantId: string,
    context: Record<string, unknown>,
  ) {
    const execution = await this.prisma.retentionExecution.create({
      data: {
        workflowId,
        userId,
        tenantId,
        status: 'PENDING',
        currentStep: 0,
        context: context as unknown as Prisma.InputJsonValue,
      },
    });
    await this.retentionQueue.add('execute-step', { executionId: execution.id });
    await this.setThrottle(workflowId, userId);
  }

  /**
   * Processes the current step of an execution. Called by the BullMQ processor.
   * Advances the execution one step at a time; schedules the next job with delay
   * when a WAIT_DAYS step is encountered.
   */
  async executeStep(executionId: string): Promise<void> {
    const execution = await this.prisma.retentionExecution.findUnique({
      where: { id: executionId },
      include: { workflow: true },
    });

    if (!execution || execution.status === 'CANCELLED' || execution.status === 'COMPLETED') return;

    const steps = execution.workflow.steps as unknown as RetentionStepDto[];
    if (execution.currentStep >= steps.length) {
      await this.prisma.retentionExecution.update({
        where: { id: executionId },
        data: { status: 'COMPLETED' },
      });
      return;
    }

    await this.prisma.retentionExecution.update({
      where: { id: executionId },
      data: { status: 'RUNNING' },
    });

    const step = steps[execution.currentStep];

    try {
      await this.runStep(step, execution);

      const nextStep = execution.currentStep + 1;

      if (nextStep >= steps.length) {
        await this.prisma.retentionExecution.update({
          where: { id: executionId },
          data: { status: 'COMPLETED', currentStep: nextStep },
        });
        return;
      }

      // Advance and schedule next step (respecting delayDays)
      await this.prisma.retentionExecution.update({
        where: { id: executionId },
        data: { status: 'PENDING', currentStep: nextStep },
      });

      const nextDelay = (steps[nextStep].delayDays ?? 0) * 24 * 60 * 60 * 1000;
      await this.retentionQueue.add(
        'execute-step',
        { executionId },
        { delay: nextDelay },
      );
    } catch (err: any) {
      this.logger.error(`Step ${execution.currentStep} failed for execution ${executionId}: ${err.message}`);
      await this.prisma.retentionExecution.update({
        where: { id: executionId },
        data: { status: 'FAILED' },
      });
    }
  }

  private async runStep(step: RetentionStepDto, execution: any): Promise<void> {
    const context = execution.context as Record<string, unknown>;

    switch (step.type as RetentionStepType) {
      case 'SEND_EMAIL':
      case 'SEND_PUSH':
        await this.notifications.sendRetentionAlertNotification(
          execution.userId,
          (context.churnScore as number) ?? 0,
          (context.recommendation as string) ?? step.config?.template ?? 'Personalized retention offer',
        );
        break;

      case 'CREATE_DISCOUNT_CODE':
        await this.createStripeDiscountForUser(execution, step);
        break;

      case 'ASSIGN_FREE_PT_SESSION':
        // Records the assignment in the execution context; trainer UI reads this
        await this.prisma.retentionExecution.update({
          where: { id: execution.id },
          data: {
            context: {
              ...(execution.context as object),
              freePtSessionAssigned: true,
              assignedAt: new Date().toISOString(),
            } as unknown as Prisma.InputJsonValue,
          },
        });
        break;

      case 'WAIT_DAYS':
        // No-op — the delay is handled at the scheduling level
        break;
    }
  }

  private async createStripeDiscountForUser(
    execution: any,
    step: RetentionStepDto,
  ): Promise<void> {
    const tenant = await this.prisma.tenant.findUnique({
      where: { id: execution.tenantId },
      select: { stripeAccountId: true },
    });

    const discountPercent = step.config?.discountPercent ?? 20;
    const code = step.config?.discountCode ?? `RET-${execution.userId.slice(0, 8).toUpperCase()}`;

    const couponParams: Stripe.CouponCreateParams = {
      percent_off: discountPercent,
      duration: 'once',
      name: `Retention offer — ${discountPercent}% off`,
      metadata: { executionId: execution.id, userId: execution.userId },
    };

    const options: Stripe.RequestOptions = tenant?.stripeAccountId
      ? { stripeAccount: tenant.stripeAccountId }
      : {};

    const coupon = await this.stripe.coupons.create(couponParams, options);
    await this.stripe.promotionCodes.create(
      { coupon: coupon.id, code },
      options,
    );

    await this.prisma.retentionExecution.update({
      where: { id: execution.id },
      data: {
        context: {
          ...(execution.context as object),
          discountCode: code,
          discountCouponId: coupon.id,
          discountPercent,
        } as unknown as Prisma.InputJsonValue,
      },
    });

    // Notify user about the discount
    await this.notifications.sendRetentionAlertNotification(
      execution.userId,
      (execution.context as any).churnScore ?? 0,
      `We have a special ${discountPercent}% discount for you. Use code: ${code}`,
    );
  }

  async cancelExecutionsForUser(tenantId: string, userId: string): Promise<void> {
    await this.prisma.retentionExecution.updateMany({
      where: { tenantId, userId, status: { in: ['PENDING', 'RUNNING'] } },
      data: { status: 'CANCELLED' },
    });
  }

  // ── Reporting ─────────────────────────────────────────────────────────────

  async listExecutions(tenantId: string, query: ListExecutionsQueryDto) {
    return this.prisma.retentionExecution.findMany({
      where: {
        tenantId,
        ...(query.workflowId && { workflowId: query.workflowId }),
        ...(query.userId && { userId: query.userId }),
        ...(query.status && { status: query.status as any }),
      },
      orderBy: { createdAt: 'desc' },
      take: query.limit ?? 50,
      include: { workflow: { select: { name: true } } },
    });
  }

  async getWorkflowStats(tenantId: string, workflowId: string) {
    await this.getWorkflow(tenantId, workflowId);
    const counts = await this.prisma.retentionExecution.groupBy({
      by: ['status'],
      where: { workflowId },
      _count: { id: true },
    });
    return counts.reduce<Record<string, number>>((acc, row) => {
      acc[row.status] = row._count.id;
      return acc;
    }, {});
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  private throttleKey(workflowId: string, userId: string) {
    return `retention:throttle:${workflowId}:${userId}`;
  }

  /**
   * Throttle check via the RetentionExecution table (no Redis dependency).
   * Returns true if a recent execution already exists within the throttle window.
   */
  private async isThrottled(workflowId: string, userId: string): Promise<boolean> {
    const cutoff = new Date(Date.now() - this.THROTTLE_TTL_SECONDS * 1000);
    const recent = await this.prisma.retentionExecution.findFirst({
      where: {
        workflowId,
        userId,
        createdAt: { gte: cutoff },
      },
      select: { id: true },
    });
    return !!recent;
  }

  // setThrottle is a no-op — the DB-based check in isThrottled is sufficient.
  private async setThrottle(_workflowId: string, _userId: string): Promise<void> {}
}
