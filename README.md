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

## 🚀 Deployment

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
