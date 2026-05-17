import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { ConfigModule } from '@nestjs/config';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { NotificationsProcessor } from './notifications.processor';
import { EmailService } from './email.service';
import { PushNotificationService } from './push-notification.service';
import { NotificationSchedulerService } from './notification-scheduler.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'notifications' }),
    ConfigModule,
    PrismaModule,
    AuthModule,
  ],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    NotificationsProcessor,
    EmailService,
    PushNotificationService,
    NotificationSchedulerService,
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
