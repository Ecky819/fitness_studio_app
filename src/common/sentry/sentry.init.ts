import * as Sentry from '@sentry/nestjs';
import { nodeProfilingIntegration } from '@sentry/profiling-node';

export function initSentry() {
    const dsn = process.env.SENTRY_DSN;
    if (!dsn) return; // Sentry is opt-in — skip if DSN is not configured

    Sentry.init({
        dsn,
        environment: process.env.NODE_ENV ?? 'development',
        release: process.env.APP_VERSION,
        integrations: [nodeProfilingIntegration()],
        tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
        profilesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
    });
}
