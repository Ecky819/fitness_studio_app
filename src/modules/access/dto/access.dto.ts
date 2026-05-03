import { IsNotEmpty, IsString } from 'class-validator';

export class GenerateAccessTokenDto {
    @IsString()
    @IsNotEmpty()
    doorId!: string;
}

export class ValidateAccessDto {
    @IsString()
    @IsNotEmpty()
    token!: string;

    @IsString()
    @IsNotEmpty()
    doorId!: string;
}

export class GenerateBleChallengeDto {
    @IsString()
    @IsNotEmpty()
    doorId!: string;

    @IsString()
    @IsNotEmpty()
    deviceId!: string;
}

export class VerifyBleChallengeDto {
    @IsString()
    @IsNotEmpty()
    challengeId!: string;

    @IsString()
    @IsNotEmpty()
    signedChallenge!: string;

    @IsString()
    @IsNotEmpty()
    doorId!: string;

    @IsString()
    @IsNotEmpty()
    deviceId!: string;
}
