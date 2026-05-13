import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreatePricingRuleDto } from './dto/pricing-rule.dto';

export interface CurrentPricing {
  baseAmountCents: number;
  modifier: number;          // fractional delta, e.g. -0.2
  finalAmountCents: number;
  discountPercent: number;   // human-friendly, e.g. 20
  activeRule: string | null; // rule name or null
  isPeakHour: boolean;
}

/**
 * Dynamic Pricing Service.
 *
 * Gym operators define time-based pricing rules (e.g. "Morning Off-Peak:
 * Mon–Fri 06:00–10:00, -20%"). The billing service calls `getCurrentModifier`
 * before creating a Stripe checkout session and applies the returned modifier
 * to the plan price.
 *
 * Rules are evaluated in order of modifier value (most negative first = best
 * deal for the customer). Only the first matching rule is applied.
 */
@Injectable()
export class PricingService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Current pricing ─────────────────────────────────────────────────────────

  async getCurrentModifier(tenantId: string, planId: string): Promise<CurrentPricing> {
    const plan = await this.prisma.plan.findFirst({
      where: { id: planId, tenantId },
      select: { amountCents: true, name: true },
    });
    if (!plan) throw new NotFoundException('Plan not found');

    const activeRule = await this.getMatchingRule(tenantId);
    const modifier = activeRule?.modifier ?? 0;
    const finalAmountCents = Math.round(plan.amountCents * (1 + modifier));

    return {
      baseAmountCents: plan.amountCents,
      modifier,
      finalAmountCents: Math.max(finalAmountCents, 0),
      discountPercent: modifier < 0 ? Math.round(-modifier * 100) : 0,
      activeRule: activeRule?.name ?? null,
      isPeakHour: modifier > 0,
    };
  }

  async getMatchingRule(tenantId: string) {
    const now = new Date();
    const isoDay = now.getDay() === 0 ? 7 : now.getDay(); // Sun=0 → 7
    const currentTime = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

    const rules = await this.prisma.pricingRule.findMany({
      where: { tenantId, isActive: true },
      orderBy: { modifier: 'asc' }, // most negative (best discount) first
    });

    return (
      rules.find(
        (r) =>
          r.daysOfWeek.includes(isoDay) &&
          currentTime >= r.timeFrom &&
          currentTime < r.timeTo,
      ) ?? null
    );
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  async listRules(tenantId: string) {
    return this.prisma.pricingRule.findMany({
      where: { tenantId },
      orderBy: [{ isActive: 'desc' }, { timeFrom: 'asc' }],
    });
  }

  async createRule(tenantId: string, dto: CreatePricingRuleDto) {
    return this.prisma.pricingRule.create({
      data: {
        tenantId,
        name: dto.name,
        daysOfWeek: dto.daysOfWeek,
        timeFrom: dto.timeFrom,
        timeTo: dto.timeTo,
        modifier: dto.modifier,
        isActive: dto.isActive ?? true,
      },
    });
  }

  async deleteRule(tenantId: string, ruleId: string) {
    const rule = await this.prisma.pricingRule.findFirst({
      where: { id: ruleId, tenantId },
    });
    if (!rule) throw new NotFoundException('Pricing rule not found');
    return this.prisma.pricingRule.delete({ where: { id: ruleId } });
  }

  async toggleRule(tenantId: string, ruleId: string) {
    const rule = await this.prisma.pricingRule.findFirst({
      where: { id: ruleId, tenantId },
    });
    if (!rule) throw new NotFoundException('Pricing rule not found');
    return this.prisma.pricingRule.update({
      where: { id: ruleId },
      data: { isActive: !rule.isActive },
    });
  }
}
