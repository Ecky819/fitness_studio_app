# Stripe CLI Setup

## Voraussetzungen

- Stripe CLI installiert
- Lokales Backend läuft auf `http://localhost:3000`
- `.env` enthält:
  - `STRIPE_SECRET_KEY`
  - `STRIPE_WEBHOOK_SECRET`
  - `FRONTEND_URL`

## 1. Stripe CLI Login

Führe folgenden Befehl aus und folge den Anweisungen im Browser:

```bash
stripe login
```

Alternativ kannst du bei CLI-Versionen mit API-Key authentifizieren:

```bash
stripe login --api-key sk_test_your_stripe_secret_key_here
```

## 2. Stripe Listener starten

Im Projektverzeichnis:

```bash
npm run stripe:listen
```

Der Listener leitet Webhook-Events an das lokale Backend weiter:

```bash
http://localhost:3000/api/billing/webhook
```

## 3. Test-Events senden

### Zahlung fehlgeschlagen

```bash
npm run stripe:trigger:payment_failed
```

### Checkout Session abgeschlossen

```bash
npm run stripe:trigger:checkout_completed
```

## 4. Weitere nützliche Befehle

### Webhook secrets anzeigen

```bash
stripe listen --print-secret
```

### Live Events testen

```bash
stripe trigger invoice.payment_failed
```

## 5. Wichtige Hinweise

- Der Listener verwendet `stripe listen --forward-to http://localhost:3000/api/billing/webhook`
- `STRIPE_WEBHOOK_SECRET` muss aus dem Stripe Dashboard stammen
- Für lokale Tests stelle sicher, dass `PORT=3000` im `.env` gesetzt ist
- Bei Erfolg sollte das Backend auf `received: true` antworten
