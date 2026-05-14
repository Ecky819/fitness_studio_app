import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import '../models/access_state.dart';
import '../services/ble_service.dart';

class AccessController extends StateNotifier<AccessState> {
  final BleService _bleService;
  final String doorId;

  Timer? _bleTimeoutTimer;
  Timer? _successTimer;

  static const bleTimeoutDuration = Duration(seconds: 3);
  static const successDisplayDuration = Duration(seconds: 1);

  AccessController(this._bleService, this.doorId)
      : super(AccessState.scanning) {
    _startAccessFlow();
  }

  void _startAccessFlow() async {
    // Cancel any existing timers
    _bleTimeoutTimer?.cancel();
    _successTimer?.cancel();

    // Start with BLE scanning
    state = AccessState.scanning;

    try {
      // Attempt BLE scan
      final deviceFound = await _bleService.scanForDevice();

      if (deviceFound) {
        state = AccessState.connecting;

        final connected = await _bleService.connect();

        if (connected) {
          state = AccessState.authenticating;

          final authenticated = await _bleService.authenticateBLE();

          if (authenticated) {
            state = AccessState.success;
            _triggerSuccessFeedback();
            // Keep success visible briefly, then transition to fallback QR
            _successTimer = Timer(successDisplayDuration, () {
              state = AccessState.fallbackQR;
            });
            return;
          }
        }
      }

      // If we reach here, BLE failed - fallback to QR
      _fallbackToQR();
    } catch (e) {
      debugPrint('BLE access failed: $e');
      _triggerErrorFeedback();
      _fallbackToQR();
    }
  }

  void _triggerSuccessFeedback() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50, amplitude: 50); // Light impact
    }
  }

  void _triggerErrorFeedback() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 200, amplitude: 128); // Heavy impact
    }
  }

  void _fallbackToQR() {
    state = AccessState.fallbackQR;
    // QR token will be fetched by the QrTokenProvider when needed
  }

  void retryAccess() {
    _startAccessFlow();
  }

  void forceQRFallback() {
    _fallbackToQR();
  }

  @override
  void dispose() {
    _bleTimeoutTimer?.cancel();
    _successTimer?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}

final accessControllerProvider =
    StateNotifierProvider.family<AccessController, AccessState, String>(
  (ref, doorId) => AccessController(BleService(), doorId),
);
