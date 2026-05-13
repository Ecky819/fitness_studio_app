import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_service.dart';
import '../models/tenant_config.dart';

/// Loads the white-label config for the current tenant.
///
/// The config is fetched once on startup and cached for the session.
/// On error (no network, unknown slug), the fallback config is returned
/// so the app always renders — it just uses default branding.
final tenantConfigProvider = FutureProvider<TenantConfig>((ref) async {
  try {
    final data = await ApiService.getTenantConfig();
    return TenantConfig.fromJson(data);
  } catch (_) {
    return TenantConfig.fallback;
  }
});

/// Synchronous access — reads the cached value or returns fallback.
/// Use this inside widgets that can't await a Future.
final tenantConfigSyncProvider = Provider<TenantConfig>((ref) {
  return ref.watch(tenantConfigProvider).maybeWhen(
        data: (config) => config,
        orElse: () => TenantConfig.fallback,
      );
});
