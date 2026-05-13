import { IsDateString, IsOptional } from 'class-validator';

export class AnalyticsDateRangeDto {
  @IsOptional()
  @IsDateString()
  dateFrom?: string;

  @IsOptional()
  @IsDateString()
  dateTo?: string;
}
