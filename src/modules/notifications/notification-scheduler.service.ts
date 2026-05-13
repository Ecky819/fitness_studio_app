import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';

@Injectable()
export class NotificationSchedulerService {
    private readonly logger = new Logger(NotificationSchedulerService.name);

    constructor(
        private readonly prisma: PrismaService,
        private readonly notificationsService: NotificationsService,
    ) { }

    // Run daily at 9 AM to check for expiring memberships
    @Cron(CronExpression.EVERY_DAY_AT_9AM)
    async checkExpiringMemberships() {
        this.logger.log('Checking for expiring memberships...');

        const sevenDaysFromNow = new Date();
        sevenDaysFromNow.setDate(sevenDaysFromNow.getDate() + 7);

        const expiringSubscriptions = await this.prisma.subscription.findMany({
            where: {
                status: 'ACTIVE',
                validUntil: {
                    lte: sevenDaysFromNow,
                    gt: new Date(), // Not already expired
                },
            },
            include: {
                user: true,
            },
        });

        for (const subscription of expiringSubscriptions) {
            const daysLeft = Math.ceil(
                (subscription.validUntil.getTime() - Date.now()) / (1000 * 60 * 60 * 24)
            );

            // Only send if not already notified in the last 24 hours
            const recentNotification = await this.prisma.accessEvent.findFirst({
                where: {
                    userId: subscription.userId,
                    status: 'GRANTED', // Using this as a proxy for notification sent
                    createdAt: {
                        gte: new Date(Date.now() - 24 * 60 * 60 * 1000), // Last 24 hours
                    },
                },
            });

            if (!recentNotification) {
                await this.notificationsService.sendMembershipExpiringNotification(
                    subscription.userId,
                    daysLeft,
                );

                this.logger.log(`Sent expiring notification to user ${subscription.userId} (${daysLeft} days left)`);
            }
        }

        this.logger.log(`Checked ${expiringSubscriptions.length} expiring memberships`);
    }
}