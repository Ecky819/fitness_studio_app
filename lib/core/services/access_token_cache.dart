import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Short-lived cache for door access tokens.
///
/// Access tokens are valid for 60 seconds on the backend, but we cache them
/// for a configurable window so the user can open the door without a
/// network round-trip on every tap (key UX requirement for a gym door).
///
/// Cache entries are stored in flutter_secure_storage as JSON:
///   { "token": "...", "expiresAt": <unix_ms> }
///
/// TTL policy:
///   - Backend token validity:  60 s
///   - Local cache TTL:         We cache until 30 s before backend expiry
///     → Prevents the user from holding a token that's about to expire.
///     → Actual reuse window: ~30 s per-door per-session.
///
/// This is intentionally conservative. For offline/edge mode (Phase 4),
/// extend this to longer TTLs with local public-key validation.
class AccessTokenCache {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _ttlSeconds = 30; // keep for 30 s (conservative)

  static String _key(String doorId) => 'access_token_cache:$doorId';

  /// Store a freshly-fetched [token] for [doorId].
  /// [backendExpiresIn] is the expiresIn string from the backend (e.g. "60s").
  static Future<void> put(String doorId, String token, {int backendExpiresInSeconds = 60}) async {
    final expiresAt = DateTime.now()
        .add(Duration(seconds: backendExpiresInSeconds - _ttlSeconds))
        .millisecondsSinceEpoch;

    await _storage.write(
      key: _key(doorId),
      value: jsonEncode({'token': token, 'expiresAt': expiresAt}),
    );
  }

  /// Returns a cached token for [doorId] if one exists and hasn't expired.
  /// Returns null otherwise (caller must fetch a new token from the backend).
  static Future<String?> get(String doorId) async {
    final raw = await _storage.read(key: _key(doorId));
    if (raw == null) return null;

    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = entry['expiresAt'] as int;

      if (DateTime.now().millisecondsSinceEpoch >= expiresAt) {
        await invalidate(doorId);
        return null;
      }

      return entry['token'] as String;
    } catch (_) {
      await invalidate(doorId);
      return null;
    }
  }

  /// Removes the cached token for [doorId].
  /// Call this after a successful or failed access attempt so the next
  /// attempt always gets a fresh token from the backend.
  static Future<void> invalidate(String doorId) =>
      _storage.delete(key: _key(doorId));

  /// Clears all cached access tokens (e.g. on logout).
  static Future<void> clearAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith('access_token_cache:')) {
        await _storage.delete(key: key);
      }
    }
  }
}
