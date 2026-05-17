-- Phase 4: Hardware Strategy
-- Adds DeviceType enum, provisioning fields, camera support, and hardware adapter config

-- DeviceType enum
CREATE TYPE "DeviceType" AS ENUM ('DOOR_CONTROLLER', 'CAMERA');

-- Device: new columns
ALTER TABLE "Device"
  ADD COLUMN "type"              "DeviceType" NOT NULL DEFAULT 'DOOR_CONTROLLER',
  ADD COLUMN "provisioningToken" TEXT         UNIQUE,
  ADD COLUMN "provisionedAt"    TIMESTAMP(3),
  ADD COLUMN "hardwareAdapter"  TEXT,
  ADD COLUMN "streamUrl"        TEXT;

-- Additional index for type-filtered queries
CREATE INDEX "Device_tenantId_type_idx" ON "Device"("tenantId", "type");

-- TenantConfig: hardware adapter default per tenant
ALTER TABLE "TenantConfig"
  ADD COLUMN "hardwareAdapter" TEXT NOT NULL DEFAULT 'ble-secure';
