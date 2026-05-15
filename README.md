# Hybrid BLE + QR Door Access System

A production-ready access control system combining Bluetooth Low Energy (BLE) proximity access with QR code fallback for secure gym door access.

## 🏗️ System Architecture

### Components

- **Flutter App**: Mobile client with BLE scanning and QR display
- **NestJS Backend**: API server with JWT tokens and validation
- **ESP32 Firmware**: Door controller with BLE server and QR scanner
- **PostgreSQL + Redis**: Database and session storage

### Security Features

- **BLE Challenge-Response**: Prevents replay attacks with HMAC-SHA256
- **JWT Access Tokens**: Short-lived (60s) with Redis-backed validation
- **Rate Limiting**: Backend-enforced per door/IP
- **Webhook Validation**: Stripe payment verification for access grants

## 🔄 Access Flow

### Primary: BLE Flow

1. App scans for ESP32 BLE devices
2. Connects and receives cryptographic challenge
3. Signs challenge with access token using HMAC-SHA256
4. Sends signed response to ESP32
5. ESP32 validates with backend
6. Door unlocks on approval

### Fallback: QR Flow

1. App requests access token from backend
2. Generates QR code with JWT token
3. User scans QR with door camera
4. ESP32 validates token with backend
5. Door unlocks on approval

### State Machine

```
Idle → BLE Scanning (3s timeout)
    ├── BLE Success → Access Granted
    └── BLE Fail → QR Generation → QR Display (45s)
        ├── QR Success → Access Granted
        └── QR Timeout → Access Denied
```

## 🚀 Backend API

### Endpoints

#### POST /access/token

Generate access token for QR flow

```json
{
  "doorId": "door_1"
}
```

#### POST /access/validate

Validate QR token

```json
{
  "token": "eyJ...",
  "doorId": "door_1"
}
```

#### POST /access/ble/challenge

Generate BLE challenge

```json
{
  "doorId": "door_1",
  "deviceId": "esp32_01"
}
```

#### POST /access/ble/verify

Verify BLE challenge response

```json
{
  "challengeId": "uuid",
  "signedChallenge": "token.signature",
  "doorId": "door_1",
  "deviceId": "esp32_01"
}
```

## 📱 Flutter App

### Key Features

- **State Management**: Riverpod for reactive UI updates
- **BLE Integration**: flutter_blue_plus for device scanning
- **QR Generation**: qr_flutter for dynamic codes
- **Auto Fallback**: Seamless BLE → QR transition
- **Security**: HMAC-SHA256 challenge signing

### Dependencies

```yaml
dependencies:
  flutter_blue_plus: ^1.32.0
  qr_flutter: ^4.1.0
  flutter_riverpod: ^2.4.0
  http: ^1.2.0
  crypto: ^3.0.3
```

## 🔧 ESP32 Firmware

### BLE Service

- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Characteristics**:
  - Challenge: `beb5483e-36e1-4688-b7f5-ea07361b26a8` (notify)
  - Response: `beb5483e-36e2-4688-b7f5-ea07361b26a8` (write)
  - Status: `beb5483e-36e3-4688-b7f5-ea07361b26a8` (notify)

### QR Scanner

- UART interface to QR scanner module
- JWT token validation via backend
- Relay control for door mechanism

### Configuration

```cpp
const char* DOOR_ID = "door_1";
const char* DEVICE_ID = "esp32_01";
const int RELAY_PIN = 26;
const int SCANNER_RX_PIN = 16;
const int SCANNER_TX_PIN = 17;
```

## 🔒 Security Implementation

### BLE Security

- **Challenge-Response**: ESP32 generates random challenge
- **HMAC Signing**: App signs challenge with access token
- **Short-lived Challenges**: 30-second expiry
- **Replay Protection**: Challenges consumed after use

### Token Security

- **JWT Format**: Standard claims with custom fields
- **Redis Storage**: Token jti tracking for replay prevention
- **Short Expiry**: 60-second lifetime
- **Rate Limiting**: 5 attempts per minute per door

### Network Security

- **TLS 1.3**: All backend communication encrypted
- **Certificate Pinning**: ESP32 validates server certificates
- **API Keys**: Device-specific authentication headers

## 🗄️ Database Schema

### Key Models

```prisma
model User {
  id        String   @id @default(cuid())
  email     String   @unique
  subscriptions Subscription[]
  accessGrants   AccessGrant[]
}

model Subscription {
  id          String   @id @default(cuid())
  userId      String
  status      SubscriptionStatus
  validUntil  DateTime
  user        User     @relation(fields: [userId], references: [id])
}

model AccessGrant {
  id          String   @id @default(cuid())
  userId      String
  active      Boolean  @default(true)
  validUntil  DateTime
  user        User     @relation(fields: [userId], references: [id])
}

model AccessAttempt {
  id          String   @id @default(cuid())
  userId      String?
  doorId      String
  grantId     String?
  success     Boolean
  reason      String
  timestamp   DateTime @default(now())
}
```

## � Local Development

1. Kopiere `.env.example` nach `.env` und fülle die Werte aus.
2. Starte PostgreSQL, Redis und den Backend-Server:

```bash
npm install
npm run build
npm run start:dev
```

### Testen

```bash
npm run test
npm run test:watch
```

### Environment Variablen

- `DATABASE_URL` – PostgreSQL-Verbindung
- `REDIS_URL` oder `REDIS_HOST`/`REDIS_PORT` – Redis-Verbindung
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` – Tokensicherheit
- `ACCESS_TOKEN_SECRET` – Kurzlebiges Türzugriffstoken
- `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` – Stripe-Zahlungsintegration
- `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` / `SMTP_FROM` – E-Mail-Versand
- `INVOICE_STORAGE_PATH` – Speicherort für erzeugte Rechnungs-PDFs

## �🚀 Deployment

### Backend

```bash
npm install
npm run build
npm run start:prod
```

### ESP32

1. Install Arduino IDE with ESP32 board support
2. Install required libraries (WiFi, BLE, HTTPClient)
3. Update configuration constants
4. Flash firmware via USB

### Flutter

```bash
flutter pub get
flutter build apk --release
```

## 🔧 Configuration

### Environment Variables

```env
# Backend
ACCESS_TOKEN_SECRET=your-secret-key
ACCESS_TOKEN_EXPIRES_IN=60s
ACCESS_VALIDATE_RATE_LIMIT=5
ACCESS_VALIDATE_WINDOW_SECONDS=60
JWT_CLOCK_TOLERANCE_SECONDS=5

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/db
REDIS_URL=redis://localhost:6379

# Stripe
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

## 📊 Monitoring

### Key Metrics

- Access success/failure rates
- BLE vs QR usage statistics
- Response time latency
- Rate limit hits
- Device connectivity status

### Logging

- All access attempts logged with reasons
- BLE connection events
- Token validation failures
- Hardware status updates

## 🧪 Testing

### Unit Tests

```bash
# Backend
npm run test

# Flutter
flutter test
```

### Integration Tests

- BLE connection scenarios
- QR code generation/validation
- Token expiry handling
- Rate limiting verification

### Hardware Tests

- Door relay operation
- QR scanner accuracy
- BLE range testing
- Power consumption profiling

## 🔮 Future Enhancements

- **NFC Support**: Additional access method
- **Mobile Credentials**: Digital wallet integration
- **Analytics Dashboard**: Access pattern insights
- **Multi-door Groups**: Campus-wide access
- **Offline Mode**: Cached credentials for network failure
- **Biometric Integration**: Face/fingerprint unlock

---

## 📞 Support

For implementation questions or issues:

- Check logs in ESP32 serial monitor
- Verify backend API responses
- Test BLE connectivity with nRF Connect app
- Validate QR codes with online decoder

This system provides enterprise-grade security with seamless user experience, designed for high-traffic gym environments with 99.9% uptime requirements.</content>
<parameter name="filePath">/Users/marcoeggert/Desktop/FLUTTER_Projekte/fitness_studio_app/README.md

Test Accounts
| Rolle | Email | Passwort | Gym Code |

|-------|-------|----------|----------|

| Admin | <admin@iron-palace.de> | Admin1234! | iron-palace |

| Member | <member@iron-palace.de> | Member1234! | iron-palace |

| Super Admin | <superadmin@gymOS.io> | SuperAdmin1234! | — |

// Startet das Backend
npm run start:dev

//Startet ohne Fehler das Backend
./start.sh

PHASE 1 — MVP-Fertigstellung        (0–8 Wochen)
├── Push Notifications (FCM/APNs)
├── Offline-Token-Cache
├── Audit-Log
├── 2FA für Admin-Accounts
├── Rate Limiting auf Auth-Endpunkten
└── Swagger API-Dokumentation

PHASE 2 — Premium AI                (8–20 Wochen)
├── Ghost Member Detection (Cron)
├── Retention Workflows (Auto-Email bei Churn)
├── Heatmap-UI im Dashboard
├── Pricing-Verwaltung UI + Member-Anzeige
└── Kapazitäts-Alerts (WebSocket)

PHASE 3 — Infra & Plattform         (parallel)
├── Docker + docker-compose
├── Kubernetes Deployment
├── Structured Logging (winston)
├── Sentry Error Tracking
├── i18n (DE/EN)
└── Responsive Web (Tablet-Breakpoint)

PHASE 4 — Hardware-Strategie        (20–40 Wochen)
├── Adapter-Layer für Kisi/Brivo/Tapkey/HID
├── OTA-Firmware-Update-Endpunkt
└── Device-Provisioning-Flow

PHASE 5 — Monetarisierung           (40+ Wochen)
├── AI-Module Feature-Gating per Tenant
├── Usage-Based Billing (Stripe Metered)
└── Marketplace-Grundlage

Phase 1 — MVP-Fertigstellung (jetzt → produktionsreif)

Was ist vollständig implementiert ✅

Mobile Access Control: BLE Challenge-Response + JWT-Token + QR-Code, Biometrie (Face ID / Touch ID), automatischer Token-Refresh
Mitgliederverwaltung: User-Modell, Subscriptions, Block/Unblock, Rollen (USER / ADMIN / TRAINER / SUPER_ADMIN)
Betreiber-Dashboard: Stats, Users (Search + Pagination), Devices, Logs, Analytics-Charts (Usage / Peaks / Revenue)
Payment Integration: Stripe Connect (per-Tenant), Checkout Sessions, Webhook-Handling (completed / failed / deleted), PDF-Rechnungen
Incident Logging: AccessEvent-Modell, gefilterte Logs-Page (Door, Datum)
Rollen & Rechte: JWT-Guard + RolesGuard + Tenant-Middleware auf allen Endpunkten

Was fehlt oder ist lückenhaft ⚠️

1. Push Notifications — fehlen komplett

Vorhanden: BullMQ-Queue + EmailService (Payment Failed, Access Revoked, Expiring)
Fehlt: Firebase Cloud Messaging (Android) / APNs (iOS)
Impact: Mitglieder bekommen keine Echtzeit-Alerts auf dem Gerät — zentrales UX-Versprechen des Produkts

Maßnahme: FCM-Integration im Backend (src/modules/notifications/), Flutter firebase_messaging Package, Push-Token bei Login speichern (User-Modell um fcmToken erweitern).

Offline-Fallback — fehlt komplett

Vorhanden: 8s BLE-Timeout → Fehlermeldung
Fehlt: Lokale Token-Zwischenspeicherung für Offline-Zugang
Impact: Kein WLAN im Studio → Tür bleibt zu

Maßnahme: Access-Token mit 15-Minuten-Gültigkeit lokal in flutter_secure_storage cachen. BLE-Verify läuft dann lokal gegen den gecachten Token (kein API-Call nötig).

Audit-Log — fehlt

Vorhanden: AccessEvent für Türzugänge
Fehlt: Wer hat im Admin-Dashboard welche Aktion durchgeführt (User geblockt, Config geändert)
Impact: Compliance-Problem für gewerbliche Betreiber

Maßnahme: AuditLog-Prisma-Modell (actorId, action, targetId, payload, createdAt), Decorator @AuditAction() für Admin-Endpunkte.

2-Faktor-Authentifizierung — fehlt

Impact: Security-Lücke für Admin-Accounts

Maßnahme: TOTP via speakeasy, QR-Code-Enrollment im Admin-Profil.

API-Dokumentation (Swagger) — fehlt

Impact: Keine Integrations-Grundlage für zukünftige Hardware-Partner oder Marketplace

Maßnahme: @nestjs/swagger Dekoratoren, auto-generierte Spec unter /api/docs.

Rate Limiting — unvollständig

Vorhanden: Rate-Limit Guard auf /access/validate
Fehlt: Per-Tenant-Limits (aktuell global), kein Limit auf Auth-Endpunkten (Brute-Force-Angriff möglich)

Maßnahme: @Throttle() auf /auth/login + /auth/register, Tenant-ID als Throttle-Key.

---

Phase 2 — Premium AI Features (Q3/Q4)

Was ist implementiert (aber zu schwach) ⚠️

Churn Risk Scoring

Vorhanden: Regel-basiertes Scoring (0–100) mit 4 Faktoren, 24h Cache in AiInsight-Modell
Schwäche: Kein echtes ML-Modell, keine automatischen Retention-Workflows (nur Score anzeigen)
Kein Frontend-UI für "Handlungsempfehlung" (Empfehlung liegt im Modell, wird aber nicht angezeigt)

Anomaly Detection

Vorhanden: 3 Regeln (RAPID_RETRIES, OFF_HOURS_ACCESS, MULTIPLE_DENIALS)
Fehlt: Tailgating Detection, Ghost Member Detection, Kamera-Integration

Occupancy

Vorhanden: Live-Counter (Redis), History (15-Min-Snapshots), WebSocket-Broadcast, Peak-Charts
Fehlt: Heatmap-Visualisierung, Kapazitäts-Schwellenwerte mit automatischen Alerts

Dynamic Pricing

Vorhanden: PricingRule-Modell (Tag / Uhrzeit / Modifier), Admin-Endpunkte
Fehlt: Frontend-UI zum Verwalten der Regeln, keine Anzeige des aktuellen Preises in der Member-App

Fehlende Premium-Features

| Feature | Masterplan-Anforderung | Aufwand |

|---|---|---|

| Tailgating Detection | AI Security | Hoch (Kamera-HW nötig) |

| Ghost Member Detection | AI Security | Mittel (Zugangsfrequenz-Analyse) |

| Heatmaps | Occupancy AI | Mittel (Frontend-Chart) |

| Dynamic Capacity Alerts | Occupancy AI | Niedrig |

| Smart Retention Workflows | Retention AI | Mittel (Auto-Email bei Score > 60) |

| Pricing-UI im Dashboard | Dynamic Pricing | Niedrig |

| Pricing-Anzeige Member-App | Dynamic Pricing | Niedrig |

Maßnahmen Phase 2:

Ghost Member Detection: Mitglieder ohne Zugang >30 Tage automatisch markieren (Cron + Anomaly-Typ GHOST_MEMBER)
Retention Workflows: BullMQ-Job bei churnScore > 60 → automatische E-Mail + Admin-Alert
Heatmap: Stunden-Matrix (7 Tage × 24 Stunden) aus OccupancySnapshot, im Dashboard als Heatmap-Grid
Pricing-Verwaltung: Flutter-Seite im Admin-Dashboard mit CRUD für PricingRule
Kapazitäts-Alerts: Threshold in TenantConfig, WebSocket-Push wenn Schwellenwert überschritten

---

Phase 3 — Architektur & Infrastruktur (parallel zu Phase 2)

Docker / Kubernetes — nicht vorhanden

Kein Dockerfile, keine docker-compose.yml, kein Helm-Chart
Impact: Kein reproduzierbares Deployment, kein Horizontal Scaling, kein HA

Maßnahme:

plaintext

Dockerfile (NestJS multi-stage build)
docker-compose.yml (postgres, redis, nestjs, nginx)
k8s/ (deployment.yaml, service.yaml, hpa.yaml, ingress.yaml)

Web Dashboard

Vorhanden: Flutter Web für Admin-Shell (kIsWeb-Check in main.dart)
Fehlt: Kein dedizierter Member-Web-Zugang (Stripe Checkout läuft extern)
Fehlt: Responsive Design für Tablet-Größen (Breakpoint nur bei 600px)

Maßnahme: Zweiten Breakpoint bei 1024px einführen, Member-Web-View mit Membership-Status + Rechnungs-Download.

Lokalisierung (i18n)

Alle Strings hardcodiert auf Englisch
Impact: Produkt nicht EU-kompatibel deploybar (DSGVO-Texte, lokale Sprachen)

Maßnahme: flutter_localizations + ARB-Dateien (DE/EN als Start), Backend-Fehler-Meldungen i18n-fähig machen.

Monitoring & Observability

Vorhanden: /health + /ready Endpunkte
Fehlt: Structured Logging (aktuell console.log), Metrics (Prometheus), Error Tracking (Sentry)

Maßnahme: @nestjs/terminus bereits via Health-Check vorhanden, winston Logger einbinden, Sentry SDK (Backend + Flutter).

---

Phase 4 — Hardware-Strategie

Phase 1 (Drittanbieter-Integration) — komplett offen

| Anbieter | API | Status |

|---|---|---|

| Kisi | REST + Webhooks | ❌ |

| Brivo | REST | ❌ |

| Tapkey | BLE + SDK | ❌ |

| HID | SDK | ❌ |

Maßnahme: Abstraktions-Layer im Backend:

plaintext

src/modules/access-hardware/
  adapters/
    kisi.adapter.ts
    brivo.adapter.ts
    tapkey.adapter.ts
  hardware-adapter.interface.ts  ← gemeinsame Schnittstelle
  hardware.service.ts            ← wählt Adapter per TenantConfig

Das bestehende BLE-Protokoll (Challenge/Response via access.service.ts) bleibt als Adapter für eigene Hardware erhalten.

Phase 2 (Eigene Hardware)

BLE Challenge-Response-Protokoll: ✅ vollständig implementiert
Fehlend: OTA-Update-Endpunkt für Firmware (PATCH /devices/{id}/firmware), Device-Provisioning-Flow (erstmaliges Pairing)
Fehlend: AI-Kamera-Integration (RTSP-Stream → Occupancy-Sensor-Input)

---

Phase 5 — Monetarisierung & Marketplace

Was funktioniert ✅

SaaS-Pläne: Starter / Pro / Enterprise via Stripe (Datenmodell vorhanden)
White-Label: TenantConfig (Logo, Farben, Domain) vollständig
Payment-Fees: Stripe Connect application_fee_amount implementiert

Was fehlt

| Revenue-Stream | Status | Maßnahme |

|---|---|---|

| Hardware-Billing | ❌ | Einmal-Kauf über Stripe (kein Subscription-Modell nötig) |

| AI-Module per Tenant | ❌ | Feature-Flags in TenantConfig.features JSON (Modell vorhanden!), pro Modul abrechenbar |

| Marketplace | ❌ | Separate Roadmap-Phase |

| Usage-Based Billing | ❌ | Metered Stripe Subscription für Zugänge/Monat |

Sofortmaßnahme (niedrigster Aufwand, höchster Return): Das features-JSON-Feld in TenantConfig ist bereits vorhanden. Dort können AI-Module (churnRisk, anomalyDetection, dynamicPricing) als booleans gesetzt und im Backend per Guard geprüft werden → Feature-Gating ohne neues Datenmodell.

---
