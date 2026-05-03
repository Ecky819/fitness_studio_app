import 'package:flutter/material.dart';

/// Premium Fitness App Color System
/// Dark mode first, high contrast, modern palette
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ===== PRIMARY COLORS =====
  /// Primary brand color - Electric Blue
  static const Color primary = Color(0xFF00D4FF);

  /// Primary variant - Deeper blue for hover states
  static const Color primaryVariant = Color(0xFF0099CC);

  /// Primary light - Lighter blue for subtle accents
  static const Color primaryLight = Color(0xFF66E0FF);

  // ===== SEMANTIC COLORS =====
  /// Success - Vibrant Green
  static const Color success = Color(0xFF00FF88);

  /// Success variant - Deeper green
  static const Color successVariant = Color(0xFF00CC66);

  /// Error - Bright Red
  static const Color error = Color(0xFFFF4444);

  /// Error variant - Deeper red
  static const Color errorVariant = Color(0xFFCC3333);

  /// Warning - Orange
  static const Color warning = Color(0xFFFFAA00);

  /// Warning variant - Deeper orange
  static const Color warningVariant = Color(0xFFCC8800);

  /// Info - Light Blue
  static const Color info = Color(0xFF44AAFF);

  // ===== BACKGROUND COLORS =====
  /// Main background - Deep navy
  static const Color background = Color(0xFF0F0F23);

  /// Secondary background - Slightly lighter navy
  static const Color backgroundSecondary = Color(0xFF1A1A2E);

  /// Tertiary background - Even lighter
  static const Color backgroundTertiary = Color(0xFF16213E);

  /// Surface color - For cards and elevated elements
  static const Color surface = Color(0xFF1E1E3F);

  /// Surface variant - Lighter surface
  static const Color surfaceVariant = Color(0xFF2A2A4A);

  // ===== TEXT COLORS =====
  /// Primary text - High contrast white
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text - Medium contrast
  static const Color textSecondary = Color(0xFFB3B3CC);

  /// Tertiary text - Low contrast
  static const Color textTertiary = Color(0xFF808099);

  /// Disabled text - Very low contrast
  static const Color textDisabled = Color(0xFF4D4D66);

  // ===== BORDER COLORS =====
  /// Default border - Subtle
  static const Color border = Color(0xFF333355);

  /// Focused border - More visible
  static const Color borderFocused = Color(0xFF555577);

  /// Divider color
  static const Color divider = Color(0xFF2A2A44);

  // ===== GRADIENT BACKGROUNDS =====
  /// Main app gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      background,
      backgroundSecondary,
      backgroundTertiary,
    ],
  );

  /// Primary gradient for buttons and highlights
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, primaryVariant],
  );

  /// Success gradient
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [success, successVariant],
  );

  /// Glass effect gradient (semi-transparent)
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1FFFFFFF),
      Color(0x0FFFFFFF),
    ],
  );

  // ===== UTILITY COLORS =====
  /// Overlay for pressed states
  static const Color overlayPressed = Color(0x1FFFFFFF);

  /// Overlay for hover states
  static const Color overlayHover = Color(0x0FFFFFFF);

  /// Shadow color
  static const Color shadow = Color(0x40000000);

  // ===== OPACITY VARIANTS =====
  /// High emphasis (87%)
  static const double highEmphasis = 0.87;

  /// Medium emphasis (60%)
  static const double mediumEmphasis = 0.60;

  /// Disabled emphasis (38%)
  static const double disabledEmphasis = 0.38;

  // ===== MATERIAL COLOR EXTENSIONS =====
  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Get surface color with elevation
  static Color surfaceWithElevation(int elevation) {
    switch (elevation) {
      case 0:
        return surface;
      case 1:
        return Color.lerp(surface, surfaceVariant, 0.1)!;
      case 2:
        return Color.lerp(surface, surfaceVariant, 0.2)!;
      case 3:
        return Color.lerp(surface, surfaceVariant, 0.3)!;
      case 4:
        return Color.lerp(surface, surfaceVariant, 0.4)!;
      default:
        return surfaceVariant;
    }
  }
}
