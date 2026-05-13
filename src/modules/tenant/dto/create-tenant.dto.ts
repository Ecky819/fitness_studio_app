import { IsEmail, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class CreateTenantDto {
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  name!: string;

  // slug becomes the subdomain: only lowercase letters, numbers, hyphens
  @IsString()
  @Matches(/^[a-z0-9-]+$/, { message: 'slug may only contain lowercase letters, numbers and hyphens' })
  @MinLength(2)
  @MaxLength(40)
  slug!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(80)
  gymName!: string;

  @IsOptional()
  @IsEmail()
  supportEmail?: string;
}
