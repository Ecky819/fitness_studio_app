import { Processor, WorkerHost } from '@nestjs/bullmq';
import { Logger } from '@nestjs/common';
import { Job } from 'bullmq';
import { EdgeService, EdgeSyncJobData } from './edge.service';

@Processor('edge-sync')
export class EdgeProcessor extends WorkerHost {
  private readonly logger = new Logger(EdgeProcessor.name);

  constructor(private readonly edgeService: EdgeService) {
    super();
  }

  async process(job: Job<EdgeSyncJobData>): Promise<void> {
    this.logger.debug(`Processing edge job ${job.name} #${job.id}`);

    switch (job.name) {
      case 'process-edge-event':
        await this.edgeService.processEvent(job.data.edgeSyncEventId);
        break;

      default:
        this.logger.warn(`Unknown edge job type: ${job.name}`);
    }
  }
}
