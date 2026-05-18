import {
  IsArray,
  IsDateString,
  IsEnum,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export enum EdgeEventType {
  ACCESS_GRANTED = 'ACCESS_GRANTED',
  ACCESS_DENIED = 'ACCESS_DENIED',
  DOOR_FORCED_OPEN = 'DOOR_FORCED_OPEN',
  DOOR_HELD_OPEN = 'DOOR_HELD_OPEN',
  DEVICE_REBOOTED = 'DEVICE_REBOOTED',
  FIRMWARE_UPDATED = 'FIRMWARE_UPDATED',
}

export class EdgeEventDto {
  @IsUUID()
  idempotencyKey!: string;

  @IsEnum(EdgeEventType)
  eventType!: EdgeEventType;

  @IsDateString()
  occurredAt!: string;

  @IsObject() @IsOptional()
  payload?: Record<string, unknown>;
}

export class BatchSyncDto {
  @IsArray() @IsNotEmpty()
  @Type(() => EdgeEventDto)
  events!: EdgeEventDto[];
}

export class EdgeSyncStatusQueryDto {
  @IsString() @IsOptional()
  @MaxLength(100)
  deviceId?: string;
}
