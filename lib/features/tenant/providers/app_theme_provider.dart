import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tenant_config.dart';
import 'tenant_provider.dart';

/// Builds a [ThemeData] driven by the current tenant's [TenantConfig].
///
/// On first paint (before the config loads), the fallback dark theme is used.
/// Once the config resolves, the theme rebuilds — typically imperceptible to
/// the user because the config request is fast.
final appThemeProvider = Provider<ThemeData>((ref) {
  final config = ref.watch(tenantConfigSyncProvider);
  return _buildTheme(config);
});

ThemeData _buildTheme(TenantConfig config) {
  final primary = config.primaryColor;
  final accent = config.accentColor;
  const background = Color(0xFF0F0F23);
  const surface = Color(0xFF1E1E3F);
  const onSurface = Colors.white;

  final colorScheme = ColorScheme.dark(
    primary: primary,
    secondary: accent,
    surface: surface,
    onSurface: onSurface,
    error: const Color(0xFFFF4444),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary.withAlpha(77)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF333355)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF333355)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFFB3B3CC)),
      hintStyle: const TextStyle(color: Color(0xFF808099)),
    ),
    cardTheme: CardTheme(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF333355)),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A2A44),
      thickness: 1,
    ),
    iconTheme: IconThemeData(color: primary),
    extensions: [
      GymThemeExtension(
        gymName: config.gymName,
        logoUrl: config.logoUrl,
        primaryGradient: LinearGradient(
          colors: [primary, primary.withAlpha(180)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        accentGradient: LinearGradient(
          colors: [accent, accent.withAlpha(180)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    ],
  );
}

/// Custom ThemeExtension carrying gym-specific tokens.
class GymThemeExtension extends ThemeExtension<GymThemeExtension> {
  final String gymName;
  final String? logoUrl;
  final LinearGradient primaryGradient;
  final LinearGradient accentGradient;

  const GymThemeExtension({
    required this.gymName,
    required this.logoUrl,
    required this.primaryGradient,
    required this.accentGradient,
  });

  @override
  GymThemeExtension copyWith({
    String? gymName,
    String? logoUrl,
    LinearGradient? primaryGradient,
    LinearGradient? accentGradient,
  }) =>
      GymThemeExtension(
        gymName: gymName ?? this.gymName,
        logoUrl: logoUrl ?? this.logoUrl,
        primaryGradient: primaryGradient ?? this.primaryGradient,
        accentGradient: accentGradient ?? this.accentGradient,
      );

  @override
  GymThemeExtension lerp(ThemeExtension<GymThemeExtension>? other, double t) {
    if (other is! GymThemeExtension) return this;
    return GymThemeExtension(
      gymName: t < 0.5 ? gymName : other.gymName,
      logoUrl: t < 0.5 ? logoUrl : other.logoUrl,
      primaryGradient: LinearGradient.lerp(primaryGradient, other.primaryGradient, t)!,
      accentGradient: LinearGradient.lerp(accentGradient, other.accentGradient, t)!,
    );
  }
}

/// Convenience extension — access gym theme tokens from BuildContext
extension GymThemeContext on BuildContext {
  GymThemeExtension get gymTheme =>
      Theme.of(this).extension<GymThemeExtension>()!;
}
