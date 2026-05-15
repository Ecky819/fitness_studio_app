import { PrismaClient, Role, TenantStatus, SaasPlan, SubscriptionStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱  Seeding database...\n');

  // ── Platform tenant (required for SUPER_ADMIN users) ─────────────────────
  const platformTenant = await prisma.tenant.upsert({
    where: { slug: 'platform' },
    update: {},
    create: {
      name: 'NextGen Gym OS Platform',
      slug: 'platform',
      status: TenantStatus.ACTIVE,
      plan: SaasPlan.ENTERPRISE,
    },
  });

  // ── Super Admin (platform-level) ──────────────────────────────────────────
  const superAdmin = await prisma.user.upsert({
    where: { tenantId_email: { tenantId: platformTenant.id, email: 'superadmin@gymOS.io' } },
    update: {},
    create: {
      tenantId: platformTenant.id,
      email: 'superadmin@gymOS.io',
      password: await bcrypt.hash('SuperAdmin1234!', 12),
      role: Role.SUPER_ADMIN,
    },
  });
  console.log(`✅  Super Admin : ${superAdmin.email}`);

  // ── Test Gym: Iron Palace ─────────────────────────────────────────────────
  const tenant = await prisma.tenant.upsert({
    where: { slug: 'iron-palace' },
    update: {},
    create: {
      name: 'Iron Palace GmbH',
      slug: 'iron-palace',
      status: TenantStatus.ACTIVE,
      plan: SaasPlan.PRO,
    },
  });
  console.log(`✅  Tenant      : ${tenant.name}  (slug: ${tenant.slug})`);

  await prisma.tenantConfig.upsert({
    where: { tenantId: tenant.id },
    update: {},
    create: {
      tenantId: tenant.id,
      gymName: 'Iron Palace',
      primaryColor: '#00D4FF',
      accentColor: '#00FF88',
      supportEmail: 'support@iron-palace.de',
      timezone: 'Europe/Berlin',
    },
  });

  // ── Plans ─────────────────────────────────────────────────────────────────
  const starterPlan = await prisma.plan.upsert({
    where: { stripePriceId: 'price_starter_monthly_test' },
    update: {},
    create: {
      tenantId: tenant.id,
      name: 'Starter',
      stripePriceId: 'price_starter_monthly_test',
      amountCents: 2900,
      interval: 'month',
      isActive: true,
    },
  });

  const proPlan = await prisma.plan.upsert({
    where: { stripePriceId: 'price_pro_monthly_test' },
    update: {},
    create: {
      tenantId: tenant.id,
      name: 'Pro',
      stripePriceId: 'price_pro_monthly_test',
      amountCents: 4900,
      interval: 'month',
      isActive: true,
    },
  });
  console.log(`✅  Plans       : ${starterPlan.name} €${(starterPlan.amountCents / 100).toFixed(2)}/mo · ${proPlan.name} €${(proPlan.amountCents / 100).toFixed(2)}/mo`);

  // ── Admin User ────────────────────────────────────────────────────────────
  const adminUser = await prisma.user.upsert({
    where: { tenantId_email: { tenantId: tenant.id, email: 'admin@iron-palace.de' } },
    update: {},
    create: {
      tenantId: tenant.id,
      email: 'admin@iron-palace.de',
      password: await bcrypt.hash('Admin1234!', 12),
      role: Role.ADMIN,
    },
  });
  console.log(`✅  Admin       : ${adminUser.email}`);

  // ── Member User ───────────────────────────────────────────────────────────
  const memberUser = await prisma.user.upsert({
    where: { tenantId_email: { tenantId: tenant.id, email: 'member@iron-palace.de' } },
    update: {},
    create: {
      tenantId: tenant.id,
      email: 'member@iron-palace.de',
      password: await bcrypt.hash('Member1234!', 12),
      role: Role.USER,
    },
  });
  console.log(`✅  Member      : ${memberUser.email}`);

  // ── Active subscription + access grant for the member ────────────────────
  const validUntil = new Date();
  validUntil.setFullYear(validUntil.getFullYear() + 1);

  const subscription = await prisma.subscription.upsert({
    where: { stripeId: 'sub_test_iron_palace_member' },
    update: {},
    create: {
      stripeId: 'sub_test_iron_palace_member',
      userId: memberUser.id,
      planId: proPlan.id,
      status: SubscriptionStatus.ACTIVE,
      validUntil,
      currentPeriodEnd: validUntil,
    },
  });

  await prisma.accessGrant.upsert({
    where: { id: 'ag_test_iron_palace_member' },
    update: {},
    create: {
      id: 'ag_test_iron_palace_member',
      userId: memberUser.id,
      active: true,
      validUntil,
    },
  });
  console.log(`✅  Subscription: ACTIVE until ${validUntil.toLocaleDateString('de-DE')}`);

  // ── Test Device (door controller) ─────────────────────────────────────────
  await prisma.device.upsert({
    where: { doorId: 'main_door' },
    update: { isOnline: true, lastSeenAt: new Date() },
    create: {
      tenantId: tenant.id,
      name: 'Haupteingang',
      doorId: 'main_door',
      location: 'Erdgeschoss',
      firmwareVersion: '2.1.0',
      isOnline: true,
      lastSeenAt: new Date(),
    },
  });
  console.log('✅  Device      : Haupteingang (doorId: main_door)');

  // ── Summary ───────────────────────────────────────────────────────────────
  console.log('\n🎉  Seed complete!\n');
  console.log('┌─────────────────────────────────────────────────────────┐');
  console.log('│  Gym Code   iron-palace                                 │');
  console.log('├─────────────────────────────────────────────────────────┤');
  console.log('│  Admin      admin@iron-palace.de   /  Admin1234!        │');
  console.log('│  Member     member@iron-palace.de  /  Member1234!       │');
  console.log('│  Platform   superadmin@gymOS.io    /  SuperAdmin1234!   │');
  console.log('└─────────────────────────────────────────────────────────┘\n');
}

main()
  .catch((e) => {
    console.error('\n❌  Seed failed:', e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
