import 'package:flutter/material.dart';
import '../colors/app_colors.dart';

/// Premium Fitness App Typography System
/// Modern, clean typography with proper hierarchy
class AppTextStyles {
  // Private constructor to prevent instantiation
  AppTextStyles._();

  // ===== BASE TEXT THEME =====
  static const String _fontFamily = 'Inter'; // Modern, clean font

  // ===== HEADINGS =====
  /// H1 - Main headings, hero text
  static TextStyle get h1 => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  /// H1 Medium - Alternative H1 with medium weight
  static TextStyle get h1Medium => h1.copyWith(fontWeight: FontWeight.w500);

  /// H2 - Section headings
  static TextStyle get h2 => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
      );

  /// H2 Medium - Alternative H2 with medium weight
  static TextStyle get h2Medium => h2.copyWith(fontWeight: FontWeight.w500);

  /// H3 - Subsection headings
  static TextStyle get h3 => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.15,
        color: AppColors.textPrimary,
      );

  /// H4 - Card titles, small headings
  static TextStyle get h4 => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.1,
        color: AppColors.textPrimary,
      );

  // ===== BODY TEXT =====
  /// Body Large - Primary body text
  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.15,
        color: AppColors.textPrimary,
      );

  /// Body - Standard body text
  static TextStyle get body => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.25,
        color: AppColors.textPrimary,
      );

  /// Body Small - Smaller body text
  static TextStyle get bodySmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.4,
        color: AppColors.textPrimary,
      );

  // ===== LABELS =====
  /// Label Large - Button text, prominent labels
  static TextStyle get labelLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      );

  /// Label - Standard labels
  static TextStyle get label => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
      );

  /// Label Small - Small labels, tags
  static TextStyle get labelSmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.4,
        letterSpacing: 0.5,
        color: AppColors.textPrimary,
      );

  // ===== CAPTIONS =====
  /// Caption - Image captions, helper text
  static TextStyle get caption => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.4,
        color: AppColors.textSecondary,
      );

  /// Overline - Small caps text above content
  static TextStyle get overline => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.5,
        letterSpacing: 1.5,
        color: AppColors.textSecondary,
        textBaseline: TextBaseline.alphabetic,
      ).apply(fontSizeFactor: 1.0);

  // ===== SEMANTIC STYLES =====
  /// Success text
  static TextStyle get success => body.copyWith(color: AppColors.success);

  /// Error text
  static TextStyle get error => body.copyWith(color: AppColors.error);

  /// Warning text
  static TextStyle get warning => body.copyWith(color: AppColors.warning);

  /// Info text
  static TextStyle get info => body.copyWith(color: AppColors.info);

  /// Secondary text
  static TextStyle get secondary =>
      body.copyWith(color: AppColors.textSecondary);

  /// Tertiary text
  static TextStyle get tertiary => body.copyWith(color: AppColors.textTertiary);

  /// Disabled text
  static TextStyle get disabled => body.copyWith(color: AppColors.textDisabled);

  // ===== BUTTON STYLES =====
  /// Primary button text
  static TextStyle get buttonPrimary => labelLarge.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      );

  /// Secondary button text
  static TextStyle get buttonSecondary => labelLarge.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      );

  /// Ghost button text
  static TextStyle get buttonGhost => labelLarge.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w500,
      );

  // ===== UTILITY METHODS =====
  /// Get text style with custom color
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// Get text style with custom weight
  static TextStyle withWeight(TextStyle style, FontWeight weight) {
    return style.copyWith(fontWeight: weight);
  }

  /// Get text style with custom size
  static TextStyle withSize(TextStyle style, double size) {
    return style.copyWith(fontSize: size);
  }

  /// Get text style with opacity
  static TextStyle withOpacity(TextStyle style, double opacity) {
    return style.copyWith(
      color: style.color?.withValues(alpha: opacity),
    );
  }
}
