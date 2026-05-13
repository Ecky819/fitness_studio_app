import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { EmailService } from './email.service';

export interface NotificationJobData {
    type: 'payment_failed' | 'access_revoked' | 'membership_expiring';
    userId: string;
    data?: any;
}

@Injectable()
export class NotificationsService {
    private readonly logger = new Logger(NotificationsService.name);

    constructor(
        @InjectQueue('notifications') private readonly notificationsQueue: Queue,
        private readonly prisma: PrismaService,
        private readonly emailService: EmailService,
    ) { }

    async sendPaymentFailedNotification(userId: string, amount: string): Promise<void> {
        await this.notificationsQueue.add('send-notification', {
            type: 'payment_failed',
            userId,
            data: { amount },
        });
    }

    async sendAccessRevokedNotification(userId: string, reason: string): Promise<void> {
        await this.notificationsQueue.add('send-notification', {
            type: 'access_revoked',
            userId,
            data: { reason },
        });
    }

    async sendMembershipExpiringNotification(userId: string, daysLeft: number): Promise<void> {
        await this.notificationsQueue.add('send-notification', {
            type: 'membership_expiring',
            userId,
            data: { daysLeft },
        });
    }

    async processNotification(job: { data: NotificationJobData }): Promise<void> {
        const { type, userId, data } = job.data;

        try {
            const user = await this.prisma.user.findUnique({
                where: { id: userId },
                select: { email: true },
            });

            if (!user) {
                this.logger.warn(`User ${userId} not found for notification`);
                return;
            }

            // Extract user name from email (basic implementation)
            const userName = user.email.split('@')[0];

            switch (type) {
                case 'payment_failed':
                    await this.emailService.sendPaymentFailedNotification(
                        user.email,
                        userName,
                        data.amount,
                    );
                    break;
                case 'access_revoked':
                    await this.emailService.sendAccessRevokedNotification(
                        user.email,
                        userName,
                        data.reason,
                    );
                    break;
                case 'membership_expiring':
                    await this.emailService.sendMembershipExpiringNotification(
                        user.email,
                        userName,
                        data.daysLeft,
                    );
                    break;
                default:
                    this.logger.warn(`Unknown notification type: ${type}`);
            }

            this.logger.log(`Notification sent: ${type} to ${user.email}`);
        } catch (error) {
            this.logger.error(`Failed to send notification ${type} to user ${userId}`, error);
            throw error;
        }
    }
}