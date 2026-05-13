import { Injectable, NestMiddleware, NotFoundException } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Resolves the current Tenant from the incoming request and attaches
 * `req.tenantId` for downstream use by TenantContextService.
 *
 * Resolution strategy (first match wins):
 *   1. X-Tenant-Slug header  (mobile app, Postman, direct API)
 *   2. Host subdomain        (slug.gymOS.io → slug)
 *
 * Health/readiness probes and super-admin routes skip tenant resolution.
 *
 * Fails with 404 if a slug is provided but doesn't match any active tenant —
 * this prevents tenant enumeration via timing differences.
 */
@Injectable()
export class TenantMiddleware implements NestMiddleware {
  constructor(private readonly prisma: PrismaService) {}

  async use(req: Request, _res: Response, next: NextFunction) {
    // Skip tenant resolution for platform-level routes
    const path = req.path;
    if (
      path.startsWith('/health') ||
      path.startsWith('/ready') ||
      path.startsWith('/api/super-admin')
    ) {
      return next();
    }

    const slug = this.extractSlug(req);

    if (!slug) {
      // No slug → no tenant context (will fail later if endpoint requires it)
      return next();
    }

    const tenant = await this.prisma.tenant.findUnique({
      where: { slug },
      select: { id: true, status: true },
    });

    if (!tenant) {
      throw new NotFoundException(`Gym not found: ${slug}`);
    }

    if (tenant.status === 'SUSPENDED' || tenant.status === 'CANCELLED') {
      throw new NotFoundException(`Gym not found: ${slug}`);
    }

    req.tenantId = tenant.id;
    next();
  }

  private extractSlug(req: Request): string | null {
    // 1. Explicit header (highest priority)
    const headerSlug = req.headers['x-tenant-slug'] as string | undefined;
    if (headerSlug?.trim()) return headerSlug.trim().toLowerCase();

    // 2. Subdomain: "iron-palace.gymOS.io" → "iron-palace"
    const host = req.headers.host ?? '';
    const subdomain = host.split('.')[0];
    // Ignore common non-tenant subdomains
    const ignored = ['www', 'api', 'app', 'localhost', '127'];
    if (subdomain && !ignored.includes(subdomain)) {
      return subdomain.toLowerCase();
    }

    return null;
  }
}
