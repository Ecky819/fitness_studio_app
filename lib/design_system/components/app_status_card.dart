import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../typography/app_text_styles.dart';
import '../spacing/app_spacing.dart';
import '../animations/app_animations.dart';

/// Status Card Component
/// Displays status information with appropriate colors and icons
enum StatusType {
  success,
  error,
  warning,
  info,
  neutral,
}

class AppStatusCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final StatusType type;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool showBorder;
  final EdgeInsetsGeometry? padding;

  const AppStatusCard({
    super.key,
    required this.title,
    this.subtitle,
    this.type = StatusType.neutral,
    this.icon,
    this.onTap,
    this.showBorder = false,
    this.padding,
  });

  Color get _backgroundColor {
    switch (type) {
      case StatusType.success:
        return AppColors.success.withValues(alpha: 0.1);
      case StatusType.error:
        return AppColors.error.withValues(alpha: 0.1);
      case StatusType.warning:
        return AppColors.warning.withValues(alpha: 0.1);
      case StatusType.info:
        return AppColors.info.withValues(alpha: 0.1);
      case StatusType.neutral:
        return AppColors.surface;
    }
  }

  Color get _borderColor {
    switch (type) {
      case StatusType.success:
        return AppColors.success;
      case StatusType.error:
        return AppColors.error;
      case StatusType.warning:
        return AppColors.warning;
      case StatusType.info:
        return AppColors.info;
      case StatusType.neutral:
        return AppColors.border;
    }
  }

  Color get _iconColor {
    switch (type) {
      case StatusType.success:
        return AppColors.success;
      case StatusType.error:
        return AppColors.error;
      case StatusType.warning:
        return AppColors.warning;
      case StatusType.info:
        return AppColors.info;
      case StatusType.neutral:
        return AppColors.textSecondary;
    }
  }

  IconData get _defaultIcon {
    switch (type) {
      case StatusType.success:
        return Icons.check_circle;
      case StatusType.error:
        return Icons.error;
      case StatusType.warning:
        return Icons.warning;
      case StatusType.info:
        return Icons.info;
      case StatusType.neutral:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.fast,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: showBorder
            ? Border.all(
                color: _borderColor.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: AppSpacing.elevationLow,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xxl,
              height: AppSpacing.xxl,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                icon ?? _defaultIcon,
                color: _iconColor,
                size: AppSpacing.iconLg,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: AppSpacing.iconMd,
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact Status Card for inline status display
class AppCompactStatusCard extends StatelessWidget {
  final String text;
  final StatusType type;
  final IconData? icon;
  final double? width;

  const AppCompactStatusCard({
    super.key,
    required this.text,
    this.type = StatusType.neutral,
    this.icon,
    this.width,
  });

  Color get _backgroundColor {
    switch (type) {
      case StatusType.success:
        return AppColors.success.withValues(alpha: 0.15);
      case StatusType.error:
        return AppColors.error.withValues(alpha: 0.15);
      case StatusType.warning:
        return AppColors.warning.withValues(alpha: 0.15);
      case StatusType.info:
        return AppColors.info.withValues(alpha: 0.15);
      case StatusType.neutral:
        return AppColors.surfaceVariant;
    }
  }

  Color get _textColor {
    switch (type) {
      case StatusType.success:
        return AppColors.success;
      case StatusType.error:
        return AppColors.error;
      case StatusType.warning:
        return AppColors.warning;
      case StatusType.info:
        return AppColors.info;
      case StatusType.neutral:
        return AppColors.textPrimary;
    }
  }

  IconData get _defaultIcon {
    switch (type) {
      case StatusType.success:
        return Icons.check;
      case StatusType.error:
        return Icons.close;
      case StatusType.warning:
        return Icons.warning;
      case StatusType.info:
        return Icons.info;
      case StatusType.neutral:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? _defaultIcon,
            color: _textColor,
            size: AppSpacing.iconSm,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: _textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
