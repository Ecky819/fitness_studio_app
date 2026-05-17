import { IsBoolean, IsDateString, IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';
import { Transform, Type } from 'class-transformer';

export class AdminLogsQueryDto {
  @IsOptional()
  @IsUUID()
  userId?: string;

  @IsOptional()
  @IsString()
  doorId?: string;

  @IsOptional()
  @IsDateString()
  dateFrom?: string;

  @IsOptional()
  @IsDateString()
  dateTo?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number = 50;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number = 0;
}

export class AdminUsersQueryDto {
  @IsOptional()
  @IsString()
  @Transform(({ value }: { value: string }) => value?.trim())
  search?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number = 50;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number = 0;
}

export class BlockUserDto {
  // body intentionally empty — action is inferred from current state
}

export class FirmwareUpdateDto {
  @IsString()
  firmwareUrl: string;

  @IsString()
  version: string;

  @IsOptional()
  @IsString()
  checksum?: string;
}

export class ProvisionDeviceDto {
  @IsString()
  doorId: string;

  @IsString()
  name: string;

  @IsString()
  location: string;

  @IsOptional()
  @IsString()
  streamUrl?: string;
}
