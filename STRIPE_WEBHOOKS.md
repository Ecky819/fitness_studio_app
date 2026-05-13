# Stripe Webhook Implementation

## Übersicht

Die Stripe Webhook-Implementierung ist vollständig und folgt der Vision: Access wird NUR via Webhook granted, nicht direkt nach Frontend-Payment.

## Implementierte Events

- `checkout.session.completed` → Erstellt Subscription & aktiviert AccessGrant
- `invoice.payment_succeeded` → Erstellt Invoice
- `invoice.payment_failed` → Setzt Subscription auf PAST_DUE & deaktiviert Access
- `customer.subscription.deleted` → Setzt Subscription auf CANCELED & deaktiviert Access

## Sicherheit

- Webhook Signature Validation mit STRIPE_WEBHOOK_SECRET
- Duplicate Event Prevention via StripeWebhookEvent Tabelle
- Rate Limiting auf Access Endpoints (10 req/min)

## Konfiguration

```env
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Webhook URL

```
POST /api/billing/webhook
```

## Testing

1. Stripe CLI: `stripe listen --forward-to localhost:3000/api/billing/webhook`
2. Test Events senden via Stripe Dashboard

## Business Logic

- AccessGrant wird nur bei erfolgreichem Payment aktiviert
- Bei Payment Failure wird Access sofort deaktiviert
- Alle Events werden geloggt für Audit Trails
