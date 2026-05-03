# Flutter Hybrid Access System Architecture

## Overview

The Flutter app implements a hybrid BLE + QR access system with seamless fallback. The app manages access state through a finite state machine and provides both BLE proximity access and QR code fallback.

## Architecture Components

### 1. State Management

```dart
enum AccessState {
  idle,
  scanningBle,
  connectingBle,
  bleChallenge,
  bleVerifying,
  qrGenerating,
  qrDisplaying,
  success,
  failed,
  timeout
}
```

### 2. Core Services

#### AccessManager (Main orchestrator)

- Manages access state machine
- Coordinates BLE and QR flows
- Handles timeouts and fallbacks

#### BleService

- BLE device scanning and connection
- Challenge-response protocol handling
- Connection state management

#### QrService

- Access token generation
- QR code generation and display
- Token refresh logic

#### BackendService

- HTTP client for API calls
- Token management
- Error handling

### 3. UI Components

#### AccessScreen (Main screen)

- State-based UI rendering
- Progress indicators
- Error messages

#### BleStatusWidget

- BLE scanning animation
- Connection status
- Signal strength

#### QrDisplayWidget

- QR code rendering
- Countdown timer
- Refresh button

### 4. State Machine Flow

```
idle → scanningBle (on access request)
scanningBle → connectingBle (device found)
connectingBle → bleChallenge (connected)
bleChallenge → bleVerifying (response sent)
bleVerifying → success (access granted)
bleVerifying → failed (access denied)

scanningBle → qrGenerating (timeout or no BLE)
qrGenerating → qrDisplaying (QR ready)
qrDisplaying → success (QR scanned)
qrDisplaying → failed (timeout/expired)
```

## Key Implementation Details

### BLE Flow

1. Scan for ESP32 devices (filter by service UUID)
2. Connect to first available device
3. Wait for challenge from device
4. Sign challenge with access token
5. Send signed response
6. Receive access decision

### QR Flow

1. Request access token from backend
2. Generate QR code with token
3. Display QR with countdown
4. Auto-refresh token before expiry

### Security

- Access tokens: JWT with short expiry (60s)
- BLE: Challenge-response with HMAC-SHA256
- Rate limiting: Backend enforced
- Token replay protection: Redis-based

### Error Handling

- BLE connection failures → fallback to QR
- Network errors → retry with backoff
- Token expiry → auto-refresh
- Device not found → QR only mode

## Dependencies

```yaml
dependencies:
  flutter_blue_plus: ^1.32.0  # BLE
  qr_flutter: ^4.1.0          # QR generation
  http: ^1.2.0                 # API calls
  flutter_riverpod: ^2.4.0     # State management
  crypto: ^3.0.3               # HMAC signing
```</content>
<parameter name="filePath">/Users/marcoeggert/Desktop/FLUTTER_Projekte/fitness_studio_app/flutter_architecture.md
