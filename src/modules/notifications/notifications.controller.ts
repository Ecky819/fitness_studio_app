import { Body, Controller, Get, HttpCode, HttpStatus, Patch, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { RegisterTokenDto } from './dto/register-token.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Role } from '../../common/enums/role.enum';

@Controller('notifications')
@UseGuards(JwtAuthGuard)
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  // Called by the mobile app immediately after login to persist the FCM token.
  @Patch('token')
  @HttpCode(HttpStatus.NO_CONTENT)
  async registerToken(
    @CurrentUser() user: { sub: string },
    @Body() dto: RegisterTokenDto,
  ): Promise<void> {
    await this.notificationsService.registerFcmToken(user.sub, dto.fcmToken);
  }

  @Get('queue-status')
  @UseGuards(RolesGuard)
  @Roles(Role.Admin)
  async getQueueStatus() {
    return this.notificationsService.getQueueStatus();
  }
}
