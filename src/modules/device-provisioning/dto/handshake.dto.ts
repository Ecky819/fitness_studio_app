import { IsString, IsOptional, Length } from 'class-validator';

export class DeviceHandshakeDto {
  @IsString()
  @Length(36, 36) // UUID
  provisioningToken!: string;

  @IsString()
  doorId!: string;

  @IsOptional()
  @IsString()
  firmwareVersion?: string;

  @IsOptional()
  @IsString()
  macAddress?: string;
}
