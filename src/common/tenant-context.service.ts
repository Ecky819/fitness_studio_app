import { Injectable, Scope, Inject, UnauthorizedException } from '@nestjs/common';
import { REQUEST } from '@nestjs/core';
import { Request } from 'express';

// Augment Express Request so TypeScript knows about our injected fields
declare module 'express' {
  interface Request {
    tenantId?: string;
    user?: {
      sub: string;
      role: string;
      tenantId?: string;
    };
  }
}

/**
 * Request-scoped service that exposes the current tenant's ID.
 *
 * Resolution order:
 *   1. req.tenantId — set by TenantMiddleware from X-Tenant-Slug header
 *   2. req.user.tenantId — embedded in the JWT by AuthService
 *
 * SUPER_ADMIN requests may optionally pass X-Target-Tenant-Id to operate
 * on behalf of a specific tenant without being scoped to one themselves.
 */
@Injectable({ scope: Scope.REQUEST })
export class TenantContextService {
  constructor(@Inject(REQUEST) private readonly req: Request) {}

  get tenantId(): string {
    const id =
      (this.req.headers['x-target-tenant-id'] as string | undefined) ||
      this.req.tenantId ||
      this.req.user?.tenantId;

    if (!id) {
      throw new UnauthorizedException('Tenant context could not be resolved');
    }

    return id;
  }

  /** Returns tenantId or null — use in guards/middleware that run pre-auth */
  get tenantIdOrNull(): string | null {
    return (
      (this.req.headers['x-target-tenant-id'] as string | undefined) ||
      this.req.tenantId ||
      this.req.user?.tenantId ||
      null
    );
  }

  get isSuperAdmin(): boolean {
    return this.req.user?.role === 'SUPER_ADMIN';
  }
}
