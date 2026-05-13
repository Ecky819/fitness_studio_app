import 'package:flutter/material.dart';

/// White-label configuration loaded from GET /api/tenant/config.
/// Drives the dynamic theme, app name, and feature flags for the current gym.
class TenantConfig {
  final String tenantId;
  final String gymName;
  final Color primaryColor;
  final Color accentColor;
  final String? logoUrl;
  final String? faviconUrl;
  final String? supportEmail;
  final String? websiteUrl;
  final String timezone;
  final String plan;
  final Map<String, bool> features;

  const TenantConfig({
    required this.tenantId,
    required this.gymName,
    required this.primaryColor,
    required this.accentColor,
    this.logoUrl,
    this.faviconUrl,
    this.supportEmail,
    this.websiteUrl,
    required this.timezone,
    required this.plan,
    required this.features,
  });

  factory TenantConfig.fromJson(Map<String, dynamic> json) {
    return TenantConfig(
      tenantId: json['tenantId'] as String,
      gymName: json['gymName'] as String,
      primaryColor: _hexToColor(json['primaryColor'] as String? ?? '#00D4FF'),
      accentColor: _hexToColor(json['accentColor'] as String? ?? '#00FF88'),
      logoUrl: json['logoUrl'] as String?,
      faviconUrl: json['faviconUrl'] as String?,
      supportEmail: json['supportEmail'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      timezone: json['timezone'] as String? ?? 'Europe/Berlin',
      plan: json['plan'] as String? ?? 'STARTER',
      features: (json['features'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as bool)),
    );
  }

  bool hasFeature(String flag) => features[flag] == true;

  bool get hasAdvancedAnalytics => hasFeature('ADVANCED_ANALYTICS');
  bool get hasMultiDoor => hasFeature('MULTI_DOOR');
  bool get hasCustomBranding => hasFeature('CUSTOM_BRANDING');
  bool get hasApiAccess => hasFeature('API_ACCESS');

  /// Fallback config for offline/pre-load state
  static TenantConfig get fallback => const TenantConfig(
        tenantId: '',
        gymName: 'Gym OS',
        primaryColor: Color(0xFF00D4FF),
        accentColor: Color(0xFF00FF88),
        timezone: 'Europe/Berlin',
        plan: 'STARTER',
        features: {},
      );

  static Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    final full = clean.length == 6 ? 'FF$clean' : clean;
    return Color(int.parse(full, radix: 16));
  }
}
