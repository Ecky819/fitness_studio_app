import { SaasPlan } from '@prisma/client';
import { FeatureFlag } from '../../common/constants/feature-flags';

export interface TierLimit {
  maxDoors: number;
  maxMembers: number;
  maxAdminUsers: number;
  logRetentionDays: number;
  includedFeatures: string[];
}

export const TIER_LIMITS: Record<SaasPlan, TierLimit> = {
  STARTER: {
    maxDoors: 1,
    maxMembers: 100,
    maxAdminUsers: 1,
    logRetentionDays: 30,
    includedFeatures: [FeatureFlag.EDGE_SYNC],
  },
  PRO: {
    maxDoors: 5,
    maxMembers: 500,
    maxAdminUsers: 5,
    logRetentionDays: 90,
    includedFeatures: [
      FeatureFlag.EDGE_SYNC,
      FeatureFlag.MULTI_DOOR,
      FeatureFlag.ADVANCED_ANALYTICS,
      FeatureFlag.CHURN_RISK,
      FeatureFlag.ANOMALY_DETECTION,
      FeatureFlag.TAILGATING_DETECTION,
      FeatureFlag.RETENTION_WORKFLOWS,
    ],
  },
  ENTERPRISE: {
    maxDoors: Infinity,
    maxMembers: Infinity,
    maxAdminUsers: Infinity,
    logRetentionDays: 365,
    includedFeatures: ['*'], // all features
  },
};

// Stripe Price IDs for each SaaS plan (configured per environment).
// ENTERPRISE uses custom contracts — no self-service price.
export const SAAS_STRIPE_PRICE_ENV_KEYS: Record<SaasPlan, string | null> = {
  STARTER: 'SAAS_STRIPE_PRICE_STARTER',
  PRO: 'SAAS_STRIPE_PRICE_PRO',
  ENTERPRISE: null,
};

export const PLAN_ORDER: SaasPlan[] = ['STARTER', 'PRO', 'ENTERPRISE'];

export function isPlanAtLeast(tenantPlan: SaasPlan, required: SaasPlan): boolean {
  return PLAN_ORDER.indexOf(tenantPlan) >= PLAN_ORDER.indexOf(required);
}
