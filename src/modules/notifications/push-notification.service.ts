import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class PushNotificationService implements OnModuleInit {
  private readonly logger = new Logger(PushNotificationService.name);
  private initialized = false;

  constructor(private readonly config: ConfigService) {}

  onModuleInit(): void {
    const serviceAccountJson = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      this.logger.warn('FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled');
      return;
    }
    try {
      const serviceAccount = JSON.parse(serviceAccountJson);
      if (!admin.apps.length) {
        admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
      }
      this.initialized = true;
      this.logger.log('Firebase Admin initialized');
    } catch (e) {
      this.logger.error('Failed to initialize Firebase Admin', e);
    }
  }

  async send(fcmToken: string, payload: PushPayload): Promise<void> {
    if (!this.initialized) return;
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title: payload.title, body: payload.body },
        data: payload.data,
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
        },
        android: {
          priority: 'high',
          notification: { sound: 'default', channelId: 'gym_alerts' },
        },
      });
    } catch (e: any) {
      // Stale/invalid tokens are not fatal — log and continue
      this.logger.warn(`Push failed for token …${fcmToken.slice(-8)}: ${e.message}`);
    }
  }

  async sendMany(fcmTokens: string[], payload: PushPayload): Promise<void> {
    if (!this.initialized || fcmTokens.length === 0) return;
    await Promise.all(fcmTokens.map((token) => this.send(token, payload)));
  }
}
