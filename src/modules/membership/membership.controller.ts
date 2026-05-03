import { Controller, Get, UseGuards } from '@nestjs/common';
import { MembershipService } from './membership.service';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';

@Controller('membership')
export class MembershipController {
    constructor(private readonly membershipService: MembershipService) { }

    @UseGuards(JwtAuthGuard)
    @Get('status')
    async status(@CurrentUser() user: any) {
        return this.membershipService.getMembershipStatus(user.sub);
    }
}
