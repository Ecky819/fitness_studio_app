/**
 * Feature flag keys stored in TenantConfig.features (JSON object).
 *
 * Setting a key to `true` in the features JSON enables the feature for that tenant.
 * Example features payload:
 *   { "CHURN_RISK": true, "ANOMALY_DETECTION": false, "DYNAMIC_PRICING": true }
 *
 * Feature flags are sold as add-ons per tenant billing plan.
 */
export const FeatureFlag = {
  /** AI churn-risk scoring and retention alerts */
  CHURN_RISK: 'CHURN_RISK',

  /** AI anomaly detection (rapid denials, off-hours, ghost members) */
  ANOMALY_DETECTION: 'ANOMALY_DETECTION',

  /** Dynamic/time-based pricing rules (peak hours, off-peak discounts) */
  DYNAMIC_PRICING: 'DYNAMIC_PRICING',

  /** Usage-based billing — enables metered Stripe subscription */
  USAGE_BILLING: 'USAGE_BILLING',

  /** Multi-door support (more than one door controller per tenant) */
  MULTI_DOOR: 'MULTI_DOOR',

  /** Advanced analytics dashboards */
  ADVANCED_ANALYTICS: 'ADVANCED_ANALYTICS',

  /** Tailgating and ghost-member security detection */
  TAILGATING_DETECTION: 'TAILGATING_DETECTION',

  /** Smart retention workflows triggered by AI churn scores */
  RETENTION_WORKFLOWS: 'RETENTION_WORKFLOWS',

  /** Edge device offline-sync / event-replay pipeline */
  EDGE_SYNC: 'EDGE_SYNC',
} as const;

export type FeatureFlagKey = (typeof FeatureFlag)[keyof typeof FeatureFlag];
