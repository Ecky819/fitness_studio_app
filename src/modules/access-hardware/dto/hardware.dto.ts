import { IsString, IsOptional, IsNumber, Min, Max } from 'class-validator';

export class UnlockDoorDto {
  @IsString()
  doorId: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(60)
  durationSeconds?: number;
}

export class HardwareWebhookDto {
  @IsOptional()
  @IsString()
  signature?: string;
}
