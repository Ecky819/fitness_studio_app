import 'package:flutter/material.dart';

/// Premium Fitness App Animation System
/// Consistent animation durations and curves
class AppAnimations {
  // Private constructor to prevent instantiation
  AppAnimations._();

  // ===== DURATION CONSTANTS =====
  /// Extra fast animation (100ms)
  static const Duration extraFast = Duration(milliseconds: 100);

  /// Fast animation (200ms)
  static const Duration fast = Duration(milliseconds: 200);

  /// Normal animation (300ms)
  static const Duration normal = Duration(milliseconds: 300);

  /// Slow animation (500ms)
  static const Duration slow = Duration(milliseconds: 500);

  /// Extra slow animation (700ms)
  static const Duration extraSlow = Duration(milliseconds: 700);

  /// Bounce animation (600ms)
  static const Duration bounce = Duration(milliseconds: 600);

  /// Page transition (400ms)
  static const Duration pageTransition = Duration(milliseconds: 400);

  // ===== CURVE CONSTANTS =====
  /// Standard easing curve
  static const Curve standard = Curves.easeInOut;

  /// Fast in, slow out
  static const Curve accelerate = Curves.easeIn;

  /// Slow in, fast out
  static const Curve decelerate = Curves.easeOut;

  /// Bounce effect
  static const Curve bounceCurve = Curves.elasticOut;

  /// Smooth bounce
  static const Curve smoothBounce = Curves.elasticInOut;

  /// Linear (no easing)
  static const Curve linear = Curves.linear;

  /// Sharp entrance
  static const Curve sharp = Curves.easeInExpo;

  // ===== COMMON ANIMATIONS =====
  /// Standard fade transition
  static Widget fadeTransition({
    required Widget child,
    required Animation<double> animation,
    Key? key,
  }) {
    return FadeTransition(
      key: key,
      opacity: animation,
      child: child,
    );
  }

  /// Scale transition
  static Widget scaleTransition({
    required Widget child,
    required Animation<double> animation,
    Key? key,
  }) {
    return ScaleTransition(
      key: key,
      scale: animation,
      child: child,
    );
  }

  /// Slide transition from right
  static Widget slideFromRight({
    required Widget child,
    required Animation<double> animation,
    Key? key,
  }) {
    return SlideTransition(
      key: key,
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }

  /// Slide transition from left
  static Widget slideFromLeft({
    required Widget child,
    required Animation<double> animation,
    Key? key,
  }) {
    return SlideTransition(
      key: key,
      position: Tween<Offset>(
        begin: const Offset(-1.0, 0.0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }

  /// Slide transition from bottom
  static Widget slideFromBottom({
    required Widget child,
    required Animation<double> animation,
    Key? key,
  }) {
    return SlideTransition(
      key: key,
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  }

  /// Combined fade and scale
  static Widget fadeScaleTransition({
    required Widget child,
    required Animation<double> animation,
    Key? key,
  }) {
    return FadeTransition(
      key: key,
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: child,
      ),
    );
  }

  // ===== ANIMATED SWITCHER CONFIGS =====
  /// Standard AnimatedSwitcher configuration
  static AnimatedSwitcher standardSwitcher({
    required Widget child,
    Duration? duration,
    Key? key,
  }) {
    return AnimatedSwitcher(
      key: key,
      duration: duration ?? normal,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: animation,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Slide AnimatedSwitcher configuration
  static AnimatedSwitcher slideSwitcher({
    required Widget child,
    Duration? duration,
    Key? key,
  }) {
    return AnimatedSwitcher(
      key: key,
      duration: duration ?? normal,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // ===== UTILITY METHODS =====
  /// Create a custom tween animation
  static Animation<T> createTweenAnimation<T>({
    required TickerProvider vsync,
    required T begin,
    required T end,
    Duration? duration,
    Curve? curve,
  }) {
    final controller = AnimationController(
      duration: duration ?? normal,
      vsync: vsync,
    );

    return Tween<T>(
      begin: begin,
      end: end,
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: curve ?? standard,
      ),
    );
  }

  /// Create a pulse animation controller
  static AnimationController createPulseController({
    required TickerProvider vsync,
    Duration? duration,
  }) {
    return AnimationController(
      duration: duration ?? const Duration(milliseconds: 1500),
      vsync: vsync,
    )..repeat(reverse: true);
  }

  /// Create a bounce animation controller
  static AnimationController createBounceController({
    required TickerProvider vsync,
    Duration? duration,
  }) {
    return AnimationController(
      duration: duration ?? bounce,
      vsync: vsync,
    );
  }
}
