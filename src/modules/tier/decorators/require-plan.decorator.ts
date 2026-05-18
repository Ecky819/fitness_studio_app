import { SetMetadata } from '@nestjs/common';
import { SaasPlan } from '@prisma/client';

export const REQUIRE_PLAN_KEY = 'required_saas_plan';

/**
 * Restricts a route or controller to tenants on the specified plan or higher.
 * Must be combined with TierGuard.
 *
 * @example
 * @RequirePlan(SaasPlan.PRO)
 * @UseGuards(TierGuard)
 * getAdvancedReport() { ... }
 */
export const RequirePlan = (plan: SaasPlan) => SetMetadata(REQUIRE_PLAN_KEY, plan);
