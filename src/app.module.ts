import { MiddlewareConsumer, Module, NestModule, RequestMethod } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { BullModule } from '@nestjs/bullmq';
import { ScheduleModule } from '@nestjs/schedule';

import { AuthModule } from './modules/auth/auth.module';
import { BillingModule } from './modules/billing/billing.module';
import { InvoiceModule } from './modules/invoice/invoice.module';
import { MembershipModule } from './modules/membership/membership.module';
import { AccessModule } from './modules/access/access.module';
import { AdminModule } from './modules/admin/admin.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { HealthModule } from './modules/health/health.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { TenantModule } from './modules/tenant/tenant.module';
import { SuperAdminModule } from './modules/super-admin/super-admin.module';
// Phase 4 — AI & Edge
import { MqttModule } from './modules/mqtt/mqtt.module';
import { OccupancyModule } from './modules/occupancy/occupancy.module';
import { AiModule } from './modules/ai/ai.module';
import { PricingModule } from './modules/pricing/pricing.module';
import { PrismaModule } from './prisma/prisma.module';
import { TenantMiddleware } from './common/middleware/tenant.middleware';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
    ThrottlerModule.forRoot({ throttlers: [{ ttl: 60, limit: 10 }] }),
    BullModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => {
        const url = cfg.get<string>('REDIS_URL');
        if (url) return { connection: { url } };
        return {
          connection: {
            host: cfg.get<string>('REDIS_HOST') ?? 'localhost',
            port: parseInt(cfg.get<string>('REDIS_PORT') ?? '6379', 10),
          },
        };
      },
    }),
    ScheduleModule.forRoot(),
    PrismaModule,
    AuthModule,
    BillingModule,
    InvoiceModule,
    MembershipModule,
    AccessModule,
    AdminModule,
    AnalyticsModule,
    HealthModule,
    NotificationsModule,
    TenantModule,
    SuperAdminModule,
    // Phase 4
    MqttModule,
    OccupancyModule,
    AiModule,
    PricingModule,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(TenantMiddleware)
      .exclude(
        { path: 'health', method: RequestMethod.GET },
        { path: 'ready', method: RequestMethod.GET },
        { path: 'api/super-admin/(.*)', method: RequestMethod.ALL },
      )
      .forRoutes('*');
  }
}
