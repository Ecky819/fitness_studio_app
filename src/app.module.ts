import { Module } from '@nestjs/common';
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
import { PrismaModule } from './prisma/prisma.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            isGlobal: true,
            envFilePath: '.env',
        }),
        ThrottlerModule.forRoot({
            throttlers: [
                {
                    ttl: 60,
                    limit: 10,
                },
            ],
        }),
        BullModule.forRootAsync({
            imports: [ConfigModule],
            inject: [ConfigService],
            useFactory: async (configService: ConfigService) => {
                const redisUrl = configService.get<string>('REDIS_URL');
                if (redisUrl) {
                    return { connection: { url: redisUrl } };
                }
                return {
                    connection: {
                        host: configService.get<string>('REDIS_HOST') || 'localhost',
                        port: parseInt(configService.get<string>('REDIS_PORT') || '6379', 10),
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
    ],
})
export class AppModule { }
