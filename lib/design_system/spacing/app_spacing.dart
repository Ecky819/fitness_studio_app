/// Premium Fitness App Spacing System
/// Consistent spacing scale for margins, padding, and layout
class AppSpacing {
  // Private constructor to prevent instantiation
  AppSpacing._();

  // ===== BASE SPACING SCALE =====
  /// Extra Small - 4px
  static const double xs = 4.0;

  /// Small - 8px
  static const double sm = 8.0;

  /// Medium - 16px
  static const double md = 16.0;

  /// Large - 24px
  static const double lg = 24.0;

  /// Extra Large - 32px
  static const double xl = 32.0;

  /// 2X Large - 48px
  static const double xxl = 48.0;

  /// 3X Large - 64px
  static const double xxxl = 64.0;

  // ===== COMPONENT SPECIFIC SPACING =====
  /// Icon padding inside buttons
  static const double iconPadding = sm;

  /// Card padding
  static const double cardPadding = md;

  /// Screen padding (horizontal)
  static const double screenPaddingHorizontal = lg;

  /// Screen padding (vertical)
  static const double screenPaddingVertical = lg;

  /// List item spacing
  static const double listItemSpacing = sm;

  /// Section spacing
  static const double sectionSpacing = xl;

  /// Element spacing (between related elements)
  static const double elementSpacing = md;

  // ===== BORDER RADIUS =====
  /// Small border radius
  static const double radiusSm = 4.0;

  /// Medium border radius
  static const double radiusMd = 8.0;

  /// Large border radius
  static const double radiusLg = 12.0;

  /// Extra large border radius
  static const double radiusXl = 16.0;

  /// Full border radius (pill shape)
  static const double radiusFull = 999.0;

  // ===== ICON SIZES =====
  /// Extra small icon
  static const double iconXs = 12.0;

  /// Small icon
  static const double iconSm = 16.0;

  /// Medium icon
  static const double iconMd = 20.0;

  /// Large icon
  static const double iconLg = 24.0;

  /// Extra large icon
  static const double iconXl = 32.0;

  /// 2X large icon
  static const double iconXxl = 48.0;

  // ===== ELEVATION =====
  /// Low elevation
  static const double elevationLow = 2.0;

  /// Medium elevation
  static const double elevationMedium = 4.0;

  /// High elevation
  static const double elevationHigh = 8.0;

  /// Very high elevation
  static const double elevationVeryHigh = 16.0;

  // ===== UTILITY METHODS =====
  /// Get spacing multiplied by factor
  static double multiply(double spacing, double factor) {
    return spacing * factor;
  }

  /// Get spacing divided by factor
  static double divide(double spacing, double factor) {
    return spacing / factor;
  }

  /// Get spacing for grid layouts
  static double gridSpacing(int columns, double containerWidth) {
    return (containerWidth - (columns - 1) * md) / columns;
  }
}
