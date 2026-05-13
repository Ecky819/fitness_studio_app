import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import { AccessService } from './access.service';
import { GenerateAccessTokenDto, ValidateAccessDto, GenerateBleChallengeDto, VerifyBleChallengeDto } from './dto/access.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RateLimitGuard } from '../../common/guards/rate-limit.guard';

@Controller('access')
export class AccessController {
    constructor(private readonly accessService: AccessService) { }

    @UseGuards(JwtAuthGuard)
    @Post('token')
    async createToken(@CurrentUser() user: any, @Body() dto: GenerateAccessTokenDto) {
        return this.accessService.generateAccessToken(user.sub, dto.doorId);
    }

    @UseGuards(RateLimitGuard)
    @Post('validate')
    async validate(@Body() dto: ValidateAccessDto, @Req() req: Request) {
        return this.accessService.validateToken(dto.token, dto.doorId, req.ip ?? '');
    }

    @Post('ble/challenge')
    async generateChallenge(@Body() dto: GenerateBleChallengeDto) {
        return this.accessService.generateBleChallenge(dto.doorId, dto.deviceId);
    }

    @Post('ble/verify')
    async verifyChallenge(@Body() dto: VerifyBleChallengeDto) {
        return this.accessService.verifyBleChallenge(dto.challengeId, dto.signedChallenge, dto.doorId, dto.deviceId);
    }
}
