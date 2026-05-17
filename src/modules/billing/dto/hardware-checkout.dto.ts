import { IsInt, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class HardwareCheckoutDto {
  /** Stripe Price ID for the hardware product (configured in Stripe dashboard) */
  @IsString()
  stripePriceId: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  quantity?: number = 1;
}
