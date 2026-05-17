import { SetMetadata } from '@nestjs/common';
import { FeatureFlagKey } from '../constants/feature-flags';

export const REQUIRE_FEATURE_KEY = 'require_feature';

/** Mark a controller or route handler as requiring a specific feature flag. */
export const RequireFeature = (flag: FeatureFlagKey) =>
  SetMetadata(REQUIRE_FEATURE_KEY, flag);
