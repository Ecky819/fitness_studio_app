import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/access_state.dart';
import '../../controllers/access_controller.dart';
import '../../providers/qr_token_provider.dart';

class AccessScreen extends ConsumerStatefulWidget {
  final String doorId;

  const AccessScreen({
    super.key,
    required this.doorId,
  });

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

    // Pulse animation for scanning (radar effect)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Scale animation for success
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Shake animation for error
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Fade animation for smooth transitions
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

  @override
  Widget build(BuildContext context) {
    final accessState = ref.watch(accessControllerProvider(widget.doorId));

    // Trigger animations based on state
    switch (accessState) {
      case AccessState.scanning:
        _pulseController.repeat(reverse: true);
        _scaleController.reset();
        _shakeController.reset();
        _fadeController.forward();
        break;
      case AccessState.connecting:
      case AccessState.authenticating:
        _pulseController.stop();
        _scaleController.reset();
        _shakeController.reset();
        _fadeController.forward();
        break;
      case AccessState.success:
        _pulseController.stop();
        _scaleController.forward();
        _shakeController.reset();
        _fadeController.forward();
        break;
      case AccessState.denied:
        _pulseController.stop();
        _scaleController.reset();
        _shakeController.forward();
        _fadeController.forward();
        break;
      case AccessState.fallbackQR:
        _pulseController.stop();
        _scaleController.reset();
        _shakeController.reset();
        _fadeController.forward();
        break;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F0F23),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                );
              },
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

  Widget _buildScanningView() {
    return Center(
      key: const ValueKey('scanning'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.blueAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bluetooth_searching,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'Suche Studio...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
              );
            },
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.blueAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.bluetooth_connected,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'Verbinde...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
              );
            },
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.greenAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.security,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'Prüfe Zugang...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
              );
            },
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
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.green, Colors.greenAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 15,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'Zugang gewährt',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              );
            },
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
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(sin(_shakeAnimation.value * 0.1) * 10, 0),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.redAccent],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.error,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'Kein Zugang',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQRFallbackView(WidgetRef ref) {
    final qrTokenAsync = ref.watch(qrTokenForDoorProvider(widget.doorId));

    return qrTokenAsync.when(
      data: (token) => token != null && token != 'error'
          ? _buildQRCodeView(token)
          : _buildQRErrorView(),
      loading: () => Center(
        key: const ValueKey('qr_loading'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.white, Colors.white70],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                color: Colors.black87,
                size: 40,
              ),
            ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: const Text(
                    'Lade QR-Code...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      height: 1.2,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      error: (_, __) => _buildQRErrorView(),
    );
  }

  Widget _buildQRCodeView(String token) {
    return Center(
      key: const ValueKey('qr_code'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'QR als Fallback',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
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
              );
            },
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'Code wird automatisch\naktualisiert',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              );
            },
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.orangeAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'QR-Code Fehler',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    height: 1.2,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
