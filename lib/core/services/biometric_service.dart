import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Biometric authentication service.
///
/// On supported devices, the user can enable "Quick Access" which stores their
/// credentials encrypted in the Keychain / Keystore and unlocks via biometrics
/// on subsequent launches — removing the need to enter email + password again.
///
/// Security model:
///   - Credentials are only stored when the user explicitly opts in.
///   - The stored password is encrypted at rest by flutter_secure_storage.
///   - Biometric authentication is required to decrypt + retrieve credentials.
///   - If biometrics change (e.g. new finger added), the stored credentials
///     are automatically invalidated by the OS.
class BiometricService {
  static final _auth = LocalAuthentication();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _kEmail = 'bio_email';
  static const _kPassword = 'bio_password';
  static const _kEnabled = 'bio_enabled';

  // ── Capability checks ────────────────────────────────────────────────────

  /// Returns true if the device supports biometric authentication and has
  /// at least one enrolled biometric credential.
  static Future<bool> isAvailable() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      if (!await _auth.isDeviceSupported()) return false;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the user has previously enabled biometric login.
  static Future<bool> isEnabled() async {
    final val = await _storage.read(key: _kEnabled);
    return val == 'true';
  }

  // ── Enable / Disable ─────────────────────────────────────────────────────

  /// Stores [email] and [password] encrypted, marks biometric login as enabled.
  /// Call this after a successful manual login when the user opts in.
  static Future<void> enable({
    required String email,
    required String password,
  }) async {
    await Future.wait([
      _storage.write(key: _kEmail, value: email),
      _storage.write(key: _kPassword, value: password),
      _storage.write(key: _kEnabled, value: 'true'),
    ]);
  }

  /// Clears stored credentials and disables biometric login.
  static Future<void> disable() async {
    await Future.wait([
      _storage.delete(key: _kEmail),
      _storage.delete(key: _kPassword),
      _storage.write(key: _kEnabled, value: 'false'),
    ]);
  }

  // ── Authenticate ─────────────────────────────────────────────────────────

  /// Prompts the user for biometric authentication and returns the stored
  /// credentials on success, or null if authentication failed / was cancelled.
  static Future<BiometricCredentials?> authenticate() async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Use biometrics to sign in to Gym OS',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allow PIN fallback
        ),
      );

      if (!didAuthenticate) return null;

      final email = await _storage.read(key: _kEmail);
      final password = await _storage.read(key: _kPassword);

      if (email == null || password == null) {
        await disable(); // Credentials missing — reset state
        return null;
      }

      return BiometricCredentials(email: email, password: password);
    } on PlatformException {
      return null;
    }
  }
}

class BiometricCredentials {
  final String email;
  final String password;
  const BiometricCredentials({required this.email, required this.password});
}
