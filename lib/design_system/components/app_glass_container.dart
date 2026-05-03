import 'dart:ui';
import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';

/// Glass Container Component
/// Premium frosted glass effect with blur and transparency
class AppGlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blurStrength;
  final double opacity;
  final Color? tintColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const AppGlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blurStrength = 10.0,
    this.opacity = 0.1,
    this.tintColor,
    this.border,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd),
        color: (tintColor ?? AppColors.surface).withValues(alpha: opacity),
        border: border ??
            Border.all(
              color: AppColors.border.withValues(alpha: 0.2),
              width: 1,
            ),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: blurStrength,
                spreadRadius: 0,
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurStrength,
            sigmaY: blurStrength,
          ),
          child: Container(
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: AppColors.glassGradient,
              borderRadius:
                  borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppSpacing.radiusMd),
        child: container,
      );
    }

    return container;
  }
}

/// Light Glass Container - More transparent
class AppLightGlassContainer extends AppGlassContainer {
  const AppLightGlassContainer({
    super.key,
    required super.child,
    super.width,
    super.height,
    super.padding,
    super.margin,
    super.borderRadius,
    super.border,
    super.boxShadow,
    super.onTap,
  }) : super(
          blurStrength: 5.0,
          opacity: 0.05,
        );
}

/// Heavy Glass Container - More opaque
class AppHeavyGlassContainer extends AppGlassContainer {
  const AppHeavyGlassContainer({
    super.key,
    required super.child,
    super.width,
    super.height,
    super.padding,
    super.margin,
    super.borderRadius,
    super.border,
    super.boxShadow,
    super.onTap,
  }) : super(
          blurStrength: 15.0,
          opacity: 0.2,
        );
}

/// Colored Glass Container - With tint
class AppColoredGlassContainer extends AppGlassContainer {
  const AppColoredGlassContainer({
    super.key,
    required super.child,
    required Color tintColor,
    super.width,
    super.height,
    super.padding,
    super.margin,
    super.borderRadius,
    super.blurStrength,
    super.opacity,
    super.border,
    super.boxShadow,
    super.onTap,
  }) : super(
          tintColor: tintColor,
        );
}
