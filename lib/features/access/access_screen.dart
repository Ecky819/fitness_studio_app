import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/access_state.dart';
import '../../controllers/access_controller.dart';
import '../../providers/qr_token_provider.dart';
import '../../design_system/design_system.dart';
import '../member/profile_screen.dart';

class AccessScreen extends ConsumerStatefulWidget {
  final String doorId;

  const AccessScreen({super.key, required this.doorId});

  @override
  ConsumerState<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends ConsumerState<AccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late AnimationController _shakeController;
  late AnimationController _fadeController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    _shakeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessState = ref.watch(accessControllerProvider(widget.doorId));

    switch (accessState) {
      case AccessState.scanning:
        _pulseController.repeat(reverse: true);
        _scaleController.reset();
        _shakeController.reset();
        _fadeController.forward();
      case AccessState.connecting:
      case AccessState.authenticating:
        _pulseController.stop();
        _scaleController.reset();
        _shakeController.reset();
        _fadeController.forward();
      case AccessState.success:
        _pulseController.stop();
        _scaleController.forward();
        _shakeController.reset();
        _fadeController.forward();
      case AccessState.denied:
        _pulseController.stop();
        _scaleController.reset();
        _shakeController.forward();
        _fadeController.forward();
      case AccessState.fallbackQR:
        _pulseController.stop();
        _scaleController.reset();
        _shakeController.reset();
        _fadeController.forward();
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'NextGen Gym OS',
          style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle_rounded,
              color: AppColors.textSecondary,
              size: 28,
            ),
            tooltip: 'Profile',
            onPressed: _openProfile,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: _buildContent(accessState, ref),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AccessState state, WidgetRef ref) {
    switch (state) {
      case AccessState.scanning:
        return _buildScanningView();
      case AccessState.connecting:
        return _buildConnectingView();
      case AccessState.authenticating:
        return _buildAuthenticatingView();
      case AccessState.success:
        return _buildSuccessView();
      case AccessState.denied:
        return _buildDeniedView();
      case AccessState.fallbackQR:
        return _buildQRFallbackView(ref);
    }
  }

  // ── BLE States ────────────────────────────────────────────────────────────

  Widget _buildScanningView() {
    return Center(
      key: const ValueKey('scanning'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnimation.value,
              child: const _StateCircle(
                color: AppColors.primary,
                icon: Icons.bluetooth_searching_rounded,
              ),
            ),
          ),
          const SizedBox(height: 40),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Scanning for device…',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Hold your phone near the door',
            style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingView() {
    return Center(
      key: const ValueKey('connecting'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _StateCircle(
            color: AppColors.primary,
            icon: Icons.bluetooth_connected_rounded,
          ),
          const SizedBox(height: 40),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Connecting…',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatingView() {
    return Center(
      key: const ValueKey('authenticating'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _StateCircle(
            color: AppColors.success,
            icon: Icons.security_rounded,
          ),
          const SizedBox(height: 40),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Verifying access…',
            style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      key: const ValueKey('success'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (_, __) => Transform.scale(
              scale: _scaleAnimation.value,
              child: const _StateCircle(
                color: AppColors.success,
                icon: Icons.check_circle_rounded,
                size: 140,
                iconSize: 80,
                glowRadius: 40,
                glowSpread: 15,
              ),
            ),
          ),
          const SizedBox(height: 40),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Access Granted',
            style: AppTextStyles.h2.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }

  Widget _buildDeniedView() {
    return Center(
      key: const ValueKey('denied'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (_, __) => Transform.translate(
              offset: Offset(sin(_shakeAnimation.value * 0.1) * 10, 0),
              child: const _StateCircle(
                color: AppColors.error,
                icon: Icons.cancel_rounded,
              ),
            ),
          ),
          const SizedBox(height: 40),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Access Denied',
            style: AppTextStyles.h2.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Your membership may be inactive',
            style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  // ── QR Fallback ───────────────────────────────────────────────────────────

  Widget _buildQRFallbackView(WidgetRef ref) {
    final qrTokenAsync = ref.watch(qrTokenForDoorProvider(widget.doorId));

    return qrTokenAsync.when(
      loading: () => Center(
        key: const ValueKey('qr_loading'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _StateCircle(
              color: AppColors.textSecondary,
              icon: Icons.qr_code_scanner_rounded,
            ),
            const SizedBox(height: 40),
            _FadeText(
              animation: _fadeAnimation,
              text: 'Preparing QR code…',
              style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w300),
            ),
          ],
        ),
      ),
      error: (_, __) => _buildQRErrorView(),
      data: (token) {
        if (token == null) return _buildQRErrorView();
        return _buildQRCodeView(token);
      },
    );
  }

  Widget _buildQRCodeView(String token) {
    return Center(
      key: const ValueKey('qr_code'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FadeText(
            animation: _fadeAnimation,
            text: 'QR Code Access',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 8),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Show this to the door scanner',
            style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: QrImageView(
                data: token,
                version: QrVersions.auto,
                size: 240.0,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Refreshes every 30 seconds',
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildQRErrorView() {
    return Center(
      key: const ValueKey('qr_error'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _StateCircle(
            color: AppColors.warning,
            icon: Icons.qr_code_rounded,
          ),
          const SizedBox(height: 40),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Could not load QR code',
            style: AppTextStyles.h3.copyWith(color: AppColors.warning),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FadeText(
            animation: _fadeAnimation,
            text: 'Check your internet connection',
            style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => ref
                .read(qrTokenForDoorProvider(widget.doorId).notifier)
                .refresh(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _StateCircle extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  final double iconSize;
  final double glowRadius;
  final double glowSpread;

  const _StateCircle({
    required this.color,
    required this.icon,
    this.size = 120,
    this.iconSize = 60,
    this.glowRadius = 30,
    this.glowSpread = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: glowRadius,
            spreadRadius: glowSpread,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

class _FadeText extends StatelessWidget {
  final Animation<double> animation;
  final String text;
  final TextStyle style;

  const _FadeText({
    required this.animation,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}
