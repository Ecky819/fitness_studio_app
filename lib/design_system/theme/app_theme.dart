import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../colors/app_colors.dart';
import '../typography/app_text_styles.dart';
import '../spacing/app_spacing.dart';

/// Premium Fitness App Theme
/// Complete theme integration with dark mode first design
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  /// Light theme (secondary)
  static ThemeData get light => _buildTheme(Brightness.light);

  /// Dark theme (primary)
  static ThemeData get dark => _buildTheme(Brightness.dark);

  /// Get theme based on brightness
  static ThemeData theme(Brightness brightness) => _buildTheme(brightness);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,

      // ===== COLORS =====
      primaryColor: AppColors.primary,
      primaryColorLight: AppColors.primaryLight,
      primaryColorDark: AppColors.primaryVariant,

      scaffoldBackgroundColor: isDark ? AppColors.background : Colors.white,
      canvasColor: isDark ? AppColors.surface : Colors.white,

      cardColor: isDark ? AppColors.surface : Colors.white,

      // ===== TEXT THEME =====
      textTheme: _buildTextTheme(isDark),

      // ===== COLOR SCHEME =====
      colorScheme: _buildColorScheme(isDark),

      // ===== COMPONENT THEMES =====
      cardTheme: _buildCardTheme(isDark),
      buttonTheme: _buildButtonTheme(isDark),
      elevatedButtonTheme: _buildElevatedButtonTheme(isDark),
      outlinedButtonTheme: _buildOutlinedButtonTheme(isDark),
      textButtonTheme: _buildTextButtonTheme(isDark),
      inputDecorationTheme: _buildInputDecorationTheme(isDark),
      dividerTheme: _buildDividerTheme(isDark),
      bottomNavigationBarTheme: _buildBottomNavigationBarTheme(isDark),
      dialogTheme: _buildDialogTheme(isDark),

      // ===== SYSTEM UI =====
      appBarTheme: _buildAppBarTheme(isDark).copyWith(
        systemOverlayStyle: _buildSystemUiOverlayStyle(isDark),
      ),

      // ===== ANIMATIONS =====
      pageTransitionsTheme: _buildPageTransitionsTheme(),

      // ===== VISUAL DENSITY =====
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  static TextTheme _buildTextTheme(bool isDark) {
    return TextTheme(
      // Headlines
      headlineLarge: AppTextStyles.h1,
      headlineMedium: AppTextStyles.h2,
      headlineSmall: AppTextStyles.h3,

      // Titles
      titleLarge: AppTextStyles.h4,
      titleMedium: AppTextStyles.bodyLarge,
      titleSmall: AppTextStyles.body,

      // Body
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.body,
      bodySmall: AppTextStyles.bodySmall,

      // Labels
      labelLarge: AppTextStyles.labelLarge,
      labelMedium: AppTextStyles.label,
      labelSmall: AppTextStyles.labelSmall,

      // Display (for special cases)
      displayLarge: AppTextStyles.h1,
      displayMedium: AppTextStyles.h2,
      displaySmall: AppTextStyles.h3,
    );
  }

  static ColorScheme _buildColorScheme(bool isDark) {
    return ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,

      // Primary colors
      primary: AppColors.primary,
      onPrimary: AppColors.textPrimary,
      primaryContainer: AppColors.primary.withValues(alpha: 0.1),
      onPrimaryContainer: AppColors.primary,

      // Secondary colors
      secondary: AppColors.primaryVariant,
      onSecondary: AppColors.textPrimary,
      secondaryContainer: AppColors.primaryVariant.withValues(alpha: 0.1),
      onSecondaryContainer: AppColors.primaryVariant,

      // Tertiary colors
      tertiary: AppColors.info,
      onTertiary: AppColors.textPrimary,
      tertiaryContainer: AppColors.info.withValues(alpha: 0.1),
      onTertiaryContainer: AppColors.info,

      // Error colors
      error: AppColors.error,
      onError: AppColors.textPrimary,
      errorContainer: AppColors.error.withValues(alpha: 0.1),
      onErrorContainer: AppColors.error,

      // Surface colors
      surface: isDark ? AppColors.surface : Colors.white,
      onSurface: isDark ? AppColors.textPrimary : Colors.black87,
      surfaceContainerHighest:
          isDark ? AppColors.surfaceVariant : Colors.grey[50]!,
      onSurfaceVariant: isDark ? AppColors.textSecondary : Colors.black54,

      // Background colors
      surfaceTint: AppColors.primary.withValues(alpha: 0.1),

      // Outline
      outline: AppColors.border,
      outlineVariant: AppColors.divider,

      // Inverse (for special cases)
      inverseSurface: isDark ? Colors.white : AppColors.background,
      onInverseSurface: isDark ? AppColors.background : Colors.white,
      inversePrimary: AppColors.primaryVariant,
    );
  }

  static AppBarTheme _buildAppBarTheme(bool isDark) {
    return AppBarTheme(
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      foregroundColor: isDark ? AppColors.textPrimary : Colors.black87,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: AppTextStyles.h4,
      iconTheme: IconThemeData(
        color: isDark ? AppColors.textPrimary : Colors.black87,
        size: AppSpacing.iconLg,
      ),
      actionsIconTheme: IconThemeData(
        color: isDark ? AppColors.textPrimary : Colors.black87,
        size: AppSpacing.iconLg,
      ),
      systemOverlayStyle: _buildSystemUiOverlayStyle(isDark),
    );
  }

  static CardThemeData _buildCardTheme(bool isDark) {
    return CardThemeData(
      color: isDark ? AppColors.surface : Colors.white,
      shadowColor: AppColors.shadow,
      elevation: AppSpacing.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      margin: EdgeInsets.zero,
    );
  }

  static ButtonThemeData _buildButtonTheme(bool isDark) {
    return ButtonThemeData(
      height: 56.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );
  }

  static ElevatedButtonThemeData _buildElevatedButtonTheme(bool isDark) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textPrimary,
        elevation: AppSpacing.elevationMedium,
        shadowColor: AppColors.primary.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        textStyle: AppTextStyles.buttonPrimary,
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme(bool isDark) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        textStyle: AppTextStyles.buttonSecondary,
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme(bool isDark) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? AppColors.textSecondary : Colors.black54,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        textStyle: AppTextStyles.buttonGhost,
      ),
    );
  }

  static InputDecorationTheme _buildInputDecorationTheme(bool isDark) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.surfaceVariant : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.border,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.border,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      labelStyle: AppTextStyles.body,
      hintStyle: AppTextStyles.body.copyWith(
        color: AppColors.textTertiary,
      ),
      errorStyle: AppTextStyles.caption.copyWith(
        color: AppColors.error,
      ),
    );
  }

  static DividerThemeData _buildDividerTheme(bool isDark) {
    return const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: AppSpacing.md,
    );
  }

  static BottomNavigationBarThemeData _buildBottomNavigationBarTheme(
      bool isDark) {
    return BottomNavigationBarThemeData(
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textTertiary,
      selectedLabelStyle: AppTextStyles.caption,
      unselectedLabelStyle: AppTextStyles.caption,
      elevation: AppSpacing.elevationMedium,
      type: BottomNavigationBarType.fixed,
    );
  }

  static SystemUiOverlayStyle _buildSystemUiOverlayStyle(bool isDark) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark ? AppColors.background : Colors.white,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );
  }

  static PageTransitionsTheme _buildPageTransitionsTheme() {
    return const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    );
  }

  // ===== UTILITY METHODS =====

  /// Get theme data for the current platform brightness
  static ThemeData of(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    return theme(brightness);
  }

  /// Create a custom theme with overrides
  static ThemeData custom({
    Brightness brightness = Brightness.dark,
    Color? primaryColor,
    String? fontFamily,
  }) {
    final baseTheme = _buildTheme(brightness);

    return baseTheme.copyWith(
      primaryColor: primaryColor ?? baseTheme.primaryColor,
      textTheme: baseTheme.textTheme.apply(fontFamily: fontFamily),
    );
  }

  static DialogThemeData _buildDialogTheme(bool isDark) {
    return DialogThemeData(
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      elevation: AppSpacing.elevationMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
    );
  }
}
