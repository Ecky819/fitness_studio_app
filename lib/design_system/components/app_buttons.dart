import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../typography/app_text_styles.dart';
import '../spacing/app_spacing.dart';
import '../animations/app_animations.dart';

/// Premium Primary Button Component
/// Gradient button with hover/press states and animations
class AppPrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double? height;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const AppPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.height,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: AppAnimations.fast,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled && !widget.isLoading) {
      _scaleController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isDisabled && !widget.isLoading) {
      _scaleController.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.isDisabled && !widget.isLoading) {
      _scaleController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled =
        !widget.isDisabled && !widget.isLoading && widget.onPressed != null;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: isEnabled ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height ?? 56.0,
              decoration: BoxDecoration(
                gradient: isEnabled ? AppColors.primaryGradient : null,
                color:
                    isEnabled ? null : AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onTap: isEnabled ? widget.onPressed : null,
                  splashColor: AppColors.primary.withValues(alpha: 0.2),
                  highlightColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(
                            widget.leadingIcon,
                            color: isEnabled
                                ? AppColors.textPrimary
                                : AppColors.textDisabled,
                            size: AppSpacing.iconMd,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        if (widget.isLoading)
                          SizedBox(
                            width: AppSpacing.iconMd,
                            height: AppSpacing.iconMd,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isEnabled
                                    ? AppColors.textPrimary
                                    : AppColors.textDisabled,
                              ),
                            ),
                          )
                        else
                          Text(
                            widget.text,
                            style: isEnabled
                                ? AppTextStyles.buttonPrimary
                                : AppTextStyles.buttonPrimary.copyWith(
                                    color: AppColors.textDisabled,
                                  ),
                          ),
                        if (widget.trailingIcon != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            widget.trailingIcon,
                            color: isEnabled
                                ? AppColors.textPrimary
                                : AppColors.textDisabled,
                            size: AppSpacing.iconMd,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Secondary Button Component
class AppSecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final double? height;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const AppSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.height,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isDisabled && !isLoading && onPressed != null;

    return SizedBox(
      width: width,
      height: height ?? 56.0,
      child: OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isEnabled ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                color: isEnabled ? AppColors.primary : AppColors.textDisabled,
                size: AppSpacing.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            if (isLoading)
              SizedBox(
                width: AppSpacing.iconMd,
                height: AppSpacing.iconMd,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isEnabled ? AppColors.primary : AppColors.textDisabled,
                  ),
                ),
              )
            else
              Text(
                text,
                style: isEnabled
                    ? AppTextStyles.buttonSecondary
                    : AppTextStyles.buttonSecondary.copyWith(
                        color: AppColors.textDisabled,
                      ),
              ),
            if (trailingIcon != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                trailingIcon,
                color: isEnabled ? AppColors.primary : AppColors.textDisabled,
                size: AppSpacing.iconMd,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ghost Button Component
class AppGhostButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isDisabled;
  final double? width;
  final double? height;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const AppGhostButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isDisabled = false,
    this.width,
    this.height,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = !isDisabled && onPressed != null;

    return SizedBox(
      width: width,
      height: height ?? 56.0,
      child: TextButton(
        onPressed: isEnabled ? onPressed : null,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                color: isEnabled
                    ? AppColors.textSecondary
                    : AppColors.textDisabled,
                size: AppSpacing.iconMd,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              text,
              style: isEnabled
                  ? AppTextStyles.buttonGhost
                  : AppTextStyles.buttonGhost.copyWith(
                      color: AppColors.textDisabled,
                    ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                trailingIcon,
                color: isEnabled
                    ? AppColors.textSecondary
                    : AppColors.textDisabled,
                size: AppSpacing.iconMd,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
