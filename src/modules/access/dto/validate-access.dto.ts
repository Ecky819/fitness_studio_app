import { IsString } from 'class-validator';

export class ValidateAccessDto {
    @IsString()
    token!: string;
}
