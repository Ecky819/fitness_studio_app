import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Injectable } from '@nestjs/common';
import { NotificationsService, NotificationJobData } from './notifications.service';

@Injectable()
@Processor('notifications')
export class NotificationsProcessor extends WorkerHost {
    constructor(private readonly notificationsService: NotificationsService) {
        super();
    }

    async process(job: { data: NotificationJobData }): Promise<void> {
        await this.notificationsService.processNotification(job);
    }
}