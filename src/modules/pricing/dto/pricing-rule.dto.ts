import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreatePricingRuleDto {
  @IsString()
  name!: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(7)
  @IsIn([1, 2, 3, 4, 5, 6, 7], { each: true })
  @Type(() => Number)
  daysOfWeek!: number[];

  @IsString()
  @Matches(/^\d{2}:\d{2}$/, { message: 'timeFrom must be HH:MM' })
  timeFrom!: string;

  @IsString()
  @Matches(/^\d{2}:\d{2}$/, { message: 'timeTo must be HH:MM' })
  timeTo!: string;

  // -1.0 = free, -0.2 = 20% off, 0 = no change, 0.1 = 10% surcharge
  @IsNumber()
  @Min(-1)
  @Max(1)
  modifier!: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean = true;
}
