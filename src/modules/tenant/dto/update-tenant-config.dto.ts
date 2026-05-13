import { IsEmail, IsHexColor, IsOptional, IsString, IsUrl, MaxLength } from 'class-validator';

export class UpdateTenantConfigDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  gymName?: string;

  @IsOptional()
  @IsHexColor()
  primaryColor?: string;

  @IsOptional()
  @IsHexColor()
  accentColor?: string;

  @IsOptional()
  @IsUrl()
  logoUrl?: string;

  @IsOptional()
  @IsEmail()
  supportEmail?: string;

  @IsOptional()
  @IsUrl()
  websiteUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  timezone?: string;
}
