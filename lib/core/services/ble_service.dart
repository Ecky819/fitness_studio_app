import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../api_service.dart';

/// Result of a BLE door access attempt.
enum BleAccessResult { granted, denied, timeout, unavailable, error }

class BleAccessResponse {
  final BleAccessResult result;
  final String? message;
  const BleAccessResponse(this.result, {this.message});
}

/// BLE service for gym door access via the challenge-response protocol.
///
/// Protocol flow:
///   1. Scan for the door's BLE peripheral (advertises a known service UUID)
///   2. Connect and discover characteristics
///   3. Request challenge from backend (POST /access/ble/challenge)
///   4. Write challenge to the door's BLE characteristic
///   5. Door reads the HMAC-signed response from the mobile JWT
///   6. Backend validates via POST /access/ble/verify
///   7. Door opens if granted
///
/// This service handles both the BLE transport layer and the backend API calls.
class BleService {
  static const _gymServiceUuid = '12345678-1234-5678-1234-56789abcdef0';
  static const _challengeCharUuid = '12345678-1234-5678-1234-56789abcdef1';
  static const _responseCharUuid = '12345678-1234-5678-1234-56789abcdef2';

  static const _scanTimeout = Duration(seconds: 8);
  static const _connectTimeout = Duration(seconds: 10);

  /// Scans for a door device by [doorId], connects, runs the full
  /// challenge-response flow, and returns the access result.
  static Future<BleAccessResponse> requestAccess({
    required String doorId,
    required String accessToken,
  }) async {
    // Check BLE availability
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      return const BleAccessResponse(
        BleAccessResult.unavailable,
        message: 'Bluetooth is not enabled',
      );
    }

    BluetoothDevice? device;

    try {
      // ── Step 1: Scan for the door peripheral ─────────────────────────────
      device = await _scanForDoor(doorId);
      if (device == null) {
        return const BleAccessResponse(
          BleAccessResult.timeout,
          message: 'Door device not found. Move closer and try again.',
        );
      }

      // ── Step 2: Connect ───────────────────────────────────────────────────
      await device.connect(timeout: _connectTimeout, autoConnect: false);

      // ── Step 3: Discover services ─────────────────────────────────────────
      final services = await device.discoverServices();
      final gymService = services
          .where(
            (s) => s.uuid.toString().toLowerCase() == _gymServiceUuid,
          )
          .firstOrNull;

      if (gymService == null) {
        return const BleAccessResponse(
          BleAccessResult.error,
          message: 'Incompatible door firmware',
        );
      }

      final challengeChar = _findChar(gymService, _challengeCharUuid);
      final responseChar = _findChar(gymService, _responseCharUuid);

      if (challengeChar == null || responseChar == null) {
        return const BleAccessResponse(
          BleAccessResult.error,
          message: 'Door characteristics not found',
        );
      }

      // ── Step 4: Get device ID from BLE advertisement ──────────────────────
      final deviceId = device.remoteId.str;

      // ── Step 5: Request BLE challenge from backend ────────────────────────
      final challengeData =
          await ApiService.generateBleChallenge(doorId, deviceId);
      final challengeId = challengeData['challengeId'] as String;
      final challenge = challengeData['challenge'] as String;

      // ── Step 6: Write challenge to door ───────────────────────────────────
      // The door computes HMAC-SHA256(challenge, accessToken) and writes back.
      final challengePayload = jsonEncode({
        'challengeId': challengeId,
        'challenge': challenge,
        'token': accessToken,
      });
      await challengeChar.write(
        utf8.encode(challengePayload),
        withoutResponse: false,
      );

      // ── Step 7: Read signed response from door ────────────────────────────
      final responseBytes = await responseChar.read();
      final signedChallenge = utf8.decode(responseBytes);

      // ── Step 8: Verify with backend ───────────────────────────────────────
      // The backend validates the HMAC and grants/denies access.
      // The door also independently grants access on valid HMAC to support
      // offline scenarios (future: local public key validation on door).
      try {
        final verifyResult = await ApiService.post(
          '/access/ble/verify',
          {
            'challengeId': challengeId,
            'signedChallenge': signedChallenge,
            'doorId': doorId,
            'deviceId': deviceId,
          },
        );
        final granted = verifyResult['access'] == true;
        return BleAccessResponse(
          granted ? BleAccessResult.granted : BleAccessResult.denied,
          message: granted ? null : 'Access denied',
        );
      } on ApiException catch (e) {
        return BleAccessResponse(
          BleAccessResult.denied,
          message: e.message,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BleService] Error: $e');
      return const BleAccessResponse(
        BleAccessResult.error,
        message: 'BLE communication error',
      );
    } finally {
      // Always disconnect — short-lived connection per access attempt.
      try {
        await device?.disconnect();
      } catch (_) {}
    }
  }

  static Future<BluetoothDevice?> _scanForDoor(String doorId) async {
    final completer = Completer<BluetoothDevice?>();
    StreamSubscription? sub;
    Timer? timer;

    timer = Timer(_scanTimeout, () {
      sub?.cancel();
      FlutterBluePlus.stopScan();
      if (!completer.isCompleted) completer.complete(null);
    });

    sub = FlutterBluePlus.scanResults.listen((results) {
      // Match by service UUID or by advertised name containing doorId
      for (final r in results) {
        final matchesService = r.advertisementData.serviceUuids
            .any((u) => u.toString().toLowerCase() == _gymServiceUuid);
        final matchesName = r.advertisementData.advName.contains(doorId);

        if (matchesService || matchesName) {
          timer?.cancel();
          sub?.cancel();
          FlutterBluePlus.stopScan();
          if (!completer.isCompleted) completer.complete(r.device);
          return;
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [Guid(_gymServiceUuid)],
      timeout: _scanTimeout,
    );

    return completer.future;
  }

  static BluetoothCharacteristic? _findChar(
    BluetoothService service,
    String uuid,
  ) =>
      service.characteristics
          .where((c) => c.uuid.toString().toLowerCase() == uuid)
          .firstOrNull;
}
