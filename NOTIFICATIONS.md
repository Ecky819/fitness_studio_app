# Notifications Modul

## Übersicht

Das Notifications Modul implementiert ein vollständiges event-getriebenes Email-Benachrichtigungssystem für alle kritischen Business Events des Fitness Studios.

## Architektur

- **BullMQ Queue**: Async Processing von Notifications
- **Email Service**: Nodemailer-basierte Email-Versendung
- **Scheduler Service**: Cron Jobs für zeitbasierte Notifications
- **Event Integration**: Automatische Triggers bei Payment Events

## Implementierte Notifications

### 1. Payment Failed ✅

**Trigger**: `invoice.payment_failed` Webhook
**Empfänger**: Betroffener User
**Inhalt**: Payment gescheitert, Access möglicherweise eingeschränkt, Link zum Update

### 2. Access Revoked ✅

**Trigger**: Subscription Cancelled oder Payment Failed
**Empfänger**: Betroffener User
**Inhalt**: Access entzogen, Grund angegeben, Support kontaktieren

### 3. Membership Expiring ✅

**Trigger**: Täglicher Cron Job (9:00 Uhr)
**Empfänger**: User mit ablaufender Mitgliedschaft (< 7 Tage)
**Inhalt**: Mitgliedschaft läuft ab, Renewal-Link
**Logic**: Keine Duplicate Notifications innerhalb 24h

## Technische Implementierung

### Queue Processing

```typescript
// Async Job Processing mit BullMQ
@Processor('notifications')
export class NotificationsProcessor extends WorkerHost {
    async process(job: { data: NotificationJobData }): Promise<void> {
        await this.notificationsService.processNotification(job);
    }
}
```

### Cron Scheduler

```typescript
@Cron(CronExpression.EVERY_DAY_AT_9AM)
async checkExpiringMemberships() {
    // Check subscriptions expiring within 7 days
    // Send notifications with duplicate prevention
}
```

### Email Templates

- HTML-basierte Templates
- Konfigurierbare SMTP Settings
- Error Handling mit Logging
- User Name Extraktion aus Email

## Konfiguration

```env
REDIS_HOST=localhost
REDIS_PORT=6379
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM=noreply@fitnessstudio.com
```

## Monitoring & Admin

- Queue Status Endpoint: `GET /api/notifications/queue-status` (Admin only)
- Comprehensive Logging aller Notification Events
- Error Tracking für fehlgeschlagene Emails
- Cron Job Execution Logs

## Integration Points

- **Billing Service**: Payment Fail & Subscription Cancelled Events
- **Prisma**: User Data für Email Addresses
- **Redis**: Queue Storage
- **SMTP**: Email Delivery

## Erweiterungen (zukünftig)

- SMS Notifications (Twilio)
- Push Notifications (Firebase)
- Template System (Handlebars)
- Notification Preferences (User Settings)
- Retry Logic für failed Emails
- Notification Analytics

## Sicherheit & Reliability

- SMTP Credentials in Environment Variables
- Rate Limiting für Admin Endpoints
- Input Validation für alle Notification Data
- Async Processing verhindert Blocking
- Duplicate Prevention bei Membership Expiring
- Error Handling mit Logging

## Konfiguration

```env
REDIS_HOST=localhost
REDIS_PORT=6379
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_FROM=noreply@fitnessstudio.com
```

## Monitoring

- Queue Status Endpoint: `GET /api/notifications/queue-status` (Admin only)
- Logging aller Notification Events
- Error Tracking für fehlgeschlagene Emails

## Erweiterungen (zukünftig)

- SMS Notifications (Twilio)
- Push Notifications (Firebase)
- Template System (Handlebars)
- Notification Preferences (User Settings)
- Retry Logic für failed Emails

## Sicherheit

- SMTP Credentials in Environment Variables
- Rate Limiting für Admin Endpoints
- Input Validation für alle Notification Data
