import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { RetentionService, RetentionJobData } from './retention.service';

@Processor('retention')
export class RetentionProcessor extends WorkerHost {
  private readonly logger = new Logger(RetentionProcessor.name);

  constructor(private readonly retentionService: RetentionService) {
    super();
  }

  async process(job: Job<RetentionJobData>): Promise<void> {
    this.logger.debug(`Processing retention job ${job.name} #${job.id}`);

    switch (job.name) {
      case 'execute-step':
        await this.retentionService.executeStep(job.data.executionId);
        break;

      default:
        this.logger.warn(`Unknown retention job type: ${job.name}`);
    }
  }
}
