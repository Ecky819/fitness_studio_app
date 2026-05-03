import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class MembershipService {
    constructor(private readonly prisma: PrismaService) { }

    async getMembershipStatus(userId: string) {
        if (!userId) {
            throw new BadRequestException('userId is required');
        }

        const subscription = await this.prisma.subscription.findFirst({
            where: { userId },
            include: { plan: true },
            orderBy: { updatedAt: 'desc' },
        });

        if (!subscription) {
            return { status: 'expired', validUntil: null, planName: null };
        }

        const now = new Date();
        const validUntil = subscription.validUntil;
        let status: string = subscription.status;

        if (validUntil < now) {
            status = 'expired';
        }

        return {
            status: status === 'ACTIVE' ? 'active' : status === 'PAST_DUE' ? 'past_due' : status === 'CANCELED' ? 'canceled' : status,
            validUntil,
            planName: subscription.plan?.name || null,
        };
    }
}
