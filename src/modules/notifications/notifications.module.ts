import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsProcessor } from './notifications.processor';
import { EmailService } from './email.service';
import { NotificationSchedulerService } from './notification-scheduler.service';
import { PrismaModule } from '../../prisma/prisma.module';

@Module({
    imports: [
        BullModule.registerQueue({
            name: 'notifications',
        }),
        PrismaModule,
    ],
    controllers: [NotificationsController],
    providers: [
        NotificationsService,
        NotificationsProcessor,
        EmailService,
        NotificationSchedulerService,
    ],
    exports: [NotificationsService],
})
export class NotificationsModule { }