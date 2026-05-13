import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Real HTTP client for the NextGen Gym OS backend.
///
/// Base URL is injected via --dart-define=API_BASE_URL=... at build time.
/// Falls back to localhost for development.
///
/// Token storage:
///   - Access token  → flutter_secure_storage (Keychain / Keystore)
///   - Refresh token → flutter_secure_storage
///
/// All authenticated requests automatically attach the Bearer header.
/// On 401 the client attempts a silent token refresh once, then throws.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  // ── Token helpers ───────────────────────────────────────────────────────

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: _kAccessToken);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _kRefreshToken);

  static Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
    ]);
  }

  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Auth endpoints ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final body = await _post('/auth/login', {'email': email, 'password': password});
    await saveTokens(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
    return body;
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    final body = await _post(
      '/auth/register',
      {'email': email, 'password': password},
    );
    await saveTokens(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
    return body;
  }

  static Future<void> logout() => clearTokens();

  static Future<Map<String, dynamic>> getProfile() => _get('/auth/me');

  // ── Membership ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMembershipStatus() =>
      _get('/membership/status');

  // ── Billing ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createCheckoutSession(
    String planId,
  ) =>
      _post('/billing/create-checkout-session', {'planId': planId});

  // ── Access ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAccessToken(String doorId) =>
      _post('/access/token', {'doorId': doorId});

  static Future<Map<String, dynamic>> generateBleChallenge(
    String doorId,
    String deviceId,
  ) =>
      _post('/access/ble/challenge', {'doorId': doorId, 'deviceId': deviceId});

  // ── Admin ───────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAdminStats() => _get('/admin/stats');

  static Future<Map<String, dynamic>> getAdminUsers({
    String? search,
    int limit = 50,
    int offset = 0,
  }) =>
      _get('/admin/users', params: {
        if (search != null) 'search': search,
        'limit': '$limit',
        'offset': '$offset',
      });

  static Future<Map<String, dynamic>> getAdminDevices() =>
      _get('/admin/devices');

  static Future<Map<String, dynamic>> getAdminLogs({
    String? userId,
    String? doorId,
    String? dateFrom,
    String? dateTo,
    int limit = 50,
    int offset = 0,
  }) =>
      _get('/admin/logs', params: {
        if (userId != null) 'userId': userId,
        if (doorId != null) 'doorId': doorId,
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
        'limit': '$limit',
        'offset': '$offset',
      });

  static Future<void> toggleUserBlock(String userId) =>
      _patch('/admin/users/$userId/block', {});

  // ── Analytics ────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getAnalyticsUsage({
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = await _get('/admin/analytics/usage', params: {
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    });
    return data as List<dynamic>;
  }

  static Future<List<dynamic>> getAnalyticsPeaks({
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = await _get('/admin/analytics/peaks', params: {
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
    });
    return data as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getAnalyticsRevenue({
    String? dateFrom,
    String? dateTo,
  }) =>
      _get('/admin/analytics/revenue', params: {
        if (dateFrom != null) 'dateFrom': dateFrom,
        if (dateTo != null) 'dateTo': dateTo,
      });

  static Future<Map<String, dynamic>> getAnalyticsActiveUsers() =>
      _get('/admin/analytics/active-users');

  // ── Public pass-through for non-typed callers (e.g. BleService) ──────────

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) =>
      _post(path, body);

  // ── Internal HTTP helpers ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String> params = const {},
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);
    final token = await getAccessToken();
    final response = await http.get(uri, headers: _headers(token));

    if (response.statusCode == 401 && token != null) {
      return _retryAfterRefresh(() => http.get(uri, headers: _headers));
    }

    return _decode(response);
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final token = await getAccessToken();
    final response = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 && token != null) {
      return _retryAfterRefresh(
        () => http.post(uri, headers: _headers, body: jsonEncode(body)),
      );
    }

    return _decode(response);
  }

  static Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');
    final token = await getAccessToken();
    final response = await http.patch(
      uri,
      headers: _headers(token),
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 && token != null) {
      return _retryAfterRefresh(
        () => http.patch(uri, headers: _headers, body: jsonEncode(body)),
      );
    }

    return _decode(response);
  }

  static Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Silently refreshes the access token and retries the original request once.
  static Future<Map<String, dynamic>> _retryAfterRefresh(
    Future<http.Response> Function() request,
  ) async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) throw ApiException(401, 'Session expired');

    final refreshResponse = await http.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (refreshResponse.statusCode != 200 &&
        refreshResponse.statusCode != 201) {
      await clearTokens();
      throw ApiException(401, 'Session expired — please log in again');
    }

    final tokens = jsonDecode(refreshResponse.body) as Map<String, dynamic>;
    await saveTokens(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );

    return _decode(await request());
  }

  static Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      // Some endpoints return a List — wrap for uniform Map return type.
      if (decoded is List) return {'data': decoded};
      return decoded as Map<String, dynamic>;
    }

    Map<String, dynamic> error = {};
    try {
      error = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}

    final message = error['message'] as String? ??
        'Request failed (${response.statusCode})';

    if (kDebugMode) {
      debugPrint('[ApiService] ${response.statusCode} ${response.request?.url} — $message');
    }

    throw ApiException(response.statusCode, message);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
