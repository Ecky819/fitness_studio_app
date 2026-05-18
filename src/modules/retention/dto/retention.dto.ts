import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

// ── Step types ───────────────────────────────────────────────────────────────

export type RetentionStepType =
  | 'SEND_EMAIL'
  | 'SEND_PUSH'
  | 'CREATE_DISCOUNT_CODE'
  | 'ASSIGN_FREE_PT_SESSION'
  | 'WAIT_DAYS';

export class RetentionStepConfigDto {
  @IsString() @IsOptional()
  subject?: string;

  @IsString() @IsOptional()
  template?: string;

  @IsInt() @Min(1) @Max(100) @IsOptional()
  discountPercent?: number;

  @IsString() @IsOptional()
  discountCode?: string;
}

export class RetentionStepDto {
  @IsString() @IsNotEmpty()
  type!: RetentionStepType;

  @IsInt() @Min(0) @IsOptional()
  delayDays?: number;

  @IsOptional()
  @ValidateNested()
  @Type(() => RetentionStepConfigDto)
  config?: RetentionStepConfigDto;
}

// ── Trigger types ─────────────────────────────────────────────────────────────

export enum RetentionTriggerType {
  CHURN_SCORE_THRESHOLD = 'CHURN_SCORE_THRESHOLD',
  DAYS_INACTIVE = 'DAYS_INACTIVE',
  SUBSCRIPTION_EXPIRING = 'SUBSCRIPTION_EXPIRING',
}

// ── Workflow DTOs ─────────────────────────────────────────────────────────────

export class CreateWorkflowDto {
  @IsString() @IsNotEmpty()
  name!: string;

  @IsString() @IsOptional()
  description?: string;

  @IsEnum(RetentionTriggerType)
  triggerType!: RetentionTriggerType;

  @IsInt() @Min(0) @Max(100) @IsOptional()
  minChurnScore?: number;

  @IsInt() @Min(1) @IsOptional()
  minDaysInactive?: number;

  @IsInt() @Min(1) @IsOptional()
  daysBeforeExpiry?: number;

  @IsArray() @IsNotEmpty()
  @ValidateNested({ each: true })
  @Type(() => RetentionStepDto)
  steps!: RetentionStepDto[];
}

// Manual partial — avoids @nestjs/mapped-types dependency
export class UpdateWorkflowDto {
  @IsString() @IsNotEmpty() @IsOptional()
  name?: string;

  @IsString() @IsOptional()
  description?: string;

  @IsBoolean() @IsOptional()
  isActive?: boolean;

  @IsEnum(RetentionTriggerType) @IsOptional()
  triggerType?: RetentionTriggerType;

  @IsInt() @Min(0) @Max(100) @IsOptional()
  minChurnScore?: number;

  @IsInt() @Min(1) @IsOptional()
  minDaysInactive?: number;

  @IsInt() @Min(1) @IsOptional()
  daysBeforeExpiry?: number;

  @IsArray() @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => RetentionStepDto)
  steps?: RetentionStepDto[];
}

// ── Query DTOs ────────────────────────────────────────────────────────────────

export class ListExecutionsQueryDto {
  @IsString() @IsOptional()
  workflowId?: string;

  @IsString() @IsOptional()
  userId?: string;

  @IsString() @IsOptional()
  status?: string;

  @IsInt() @Min(1) @Max(200) @IsOptional()
  @Type(() => Number)
  limit?: number;
}
