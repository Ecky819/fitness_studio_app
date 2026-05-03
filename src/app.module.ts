import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './modules/auth/auth.module';
import { BillingModule } from './modules/billing/billing.module';
import { InvoiceModule } from './modules/invoice/invoice.module';
import { MembershipModule } from './modules/membership/membership.module';
import { AccessModule } from './modules/access/access.module';
import { AdminModule } from './modules/admin/admin.module';
import { PrismaModule } from './prisma/prisma.module';

@Module({
    imports: [
        ConfigModule.forRoot({
            isGlobal: true,
            envFilePath: '.env',
        }),
        PrismaModule,
        AuthModule,
        BillingModule,
        InvoiceModule,
        MembershipModule,
        AccessModule,
        AdminModule,
    ],
})
export class AppModule { }
