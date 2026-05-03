import { IsString, IsUUID } from 'class-validator';

export class CreateCheckoutSessionDto {
    @IsUUID()
    planId!: string;
}
