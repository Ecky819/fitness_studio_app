import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaService } from '../../prisma/prisma.service';
import { EmailService } from './email.service';
import { PushNotificationService } from './push-notification.service';

export interface NotificationJobData {
  type: 'payment_failed' | 'access_revoked' | 'membership_expiring' | 'retention_alert';
  userId: string;
  data?: Record<string, unknown>;
}

const PUSH_TEMPLATES: Record<
  NotificationJobData['type'],
  (data: Record<string, unknown>) => { title: string; body: string }
> = {
  payment_failed: (d) => ({
    title: 'Zahlung fehlgeschlagen',
    body: `Wir konnten deine Zahlung von ${d.amount ?? ''} nicht verarbeiten. Bitte aktualisiere deine Zahlungsdaten.`,
  }),
  access_revoked: (d) => ({
    title: 'Zugang gesperrt',
    body: `Dein Gym-Zugang wurde gesperrt. Grund: ${d.reason ?? 'Unbekannt'}.`,
  }),
  membership_expiring: (d) => ({
    title: 'Mitgliedschaft läuft ab',
    body: `Deine Mitgliedschaft läuft in ${d.daysLeft ?? '?'} Tagen ab. Jetzt verlängern!`,
  }),
  retention_alert: () => ({
    title: 'Wir vermissen dich!',
    body: 'Du warst eine Weile nicht im Gym. Komm vorbei und bleib am Ball!',
  }),
};

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    @InjectQueue('notifications') private readonly notificationsQueue: Queue,
    private readonly prisma: PrismaService,
    private readonly emailService: EmailService,
    private readonly push: PushNotificationService,
  ) {}

  // ── Public trigger methods ────────────────────────────────────────────────

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

  // ── FCM token registration ────────────────────────────────────────────────

  async sendRetentionAlertNotification(userId: string, churnScore: number, recommendation: string): Promise<void> {
    await this.notificationsQueue.add('send-notification', {
      type: 'retention_alert',
      userId,
      data: { churnScore, recommendation },
    });
  }

  async registerFcmToken(userId: string, fcmToken: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken },
    });
  }

  // ── BullMQ processor entry point ──────────────────────────────────────────

  async processNotification(job: { data: NotificationJobData }): Promise<void> {
    const { type, userId, data = {} } = job.data;

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { email: true, fcmToken: true },
    });

    if (!user) {
      this.logger.warn(`User ${userId} not found for notification`);
      return;
    }

    const userName = user.email.split('@')[0];

    // Send both channels in parallel; push failure never blocks email retry.
    await Promise.all([
      this.sendEmail(type, user.email, userName, data),
      this.sendPush(type, user.fcmToken, data),
    ]);

    this.logger.log(`Notification sent: ${type} → ${user.email} (push: ${!!user.fcmToken})`);
  }

  // ── Queue monitoring ──────────────────────────────────────────────────────

  async getQueueStatus() {
    const [waiting, active, completed, failed] = await Promise.all([
      this.notificationsQueue.getWaitingCount(),
      this.notificationsQueue.getActiveCount(),
      this.notificationsQueue.getCompletedCount(),
      this.notificationsQueue.getFailedCount(),
    ]);
    return { waiting, active, completed, failed };
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  private async sendEmail(
    type: NotificationJobData['type'],
    email: string,
    userName: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    switch (type) {
      case 'payment_failed':
        await this.emailService.sendPaymentFailedNotification(email, userName, String(data.amount ?? ''));
        break;
      case 'access_revoked':
        await this.emailService.sendAccessRevokedNotification(email, userName, String(data.reason ?? ''));
        break;
      case 'membership_expiring':
        await this.emailService.sendMembershipExpiringNotification(email, userName, Number(data.daysLeft ?? 0));
        break;
      case 'retention_alert':
        await this.emailService.sendRetentionAlert(email, userName, Number(data.churnScore ?? 0), String(data.recommendation ?? ''));
        break;
      default:
        this.logger.warn(`Unknown notification type: ${type}`);
    }
  }

  private async sendPush(
    type: NotificationJobData['type'],
    fcmToken: string | null,
    data: Record<string, unknown>,
  ): Promise<void> {
    if (!fcmToken) return;
    const template = PUSH_TEMPLATES[type];
    if (!template) return;
    const { title, body } = template(data);
    await this.push.send(fcmToken, { title, body, data: { type } });
  }
}
