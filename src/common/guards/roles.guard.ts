import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { Role } from '../enums/role.enum';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    // No @Roles() metadata → open to any authenticated user
    if (!requiredRoles?.length) return true;

    const { user } = context.switchToHttp().getRequest<{ user?: { role?: Role } }>();

    // JwtAuthGuard must run before RolesGuard so user is populated
    if (!user?.role) {
      throw new ForbiddenException('Access denied');
    }

    if (!requiredRoles.includes(user.role)) {
      throw new ForbiddenException(
        `Insufficient role. Required: ${requiredRoles.join(' or ')}`,
      );
    }

    return true;
  }
}
