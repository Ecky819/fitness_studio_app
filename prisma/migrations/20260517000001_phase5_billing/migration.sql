-- Phase 5: Monetization
-- Adds stripeMeteredItemId to Subscription for usage-based billing

ALTER TABLE "Subscription"
  ADD COLUMN "stripeMeteredItemId" TEXT;
