import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_controller.dart';

/// Global app controller provider
final appControllerProvider =
    StateNotifierProvider<AppControllerNotifier, AppState>((ref) {
  return AppControllerNotifier();
});

/// StateNotifier wrapper for AppController
class AppControllerNotifier extends StateNotifier<AppState> {
  final AppController _controller = AppController();

  AppControllerNotifier() : super(AppState.loading) {
    _controller.addListener(() {
      state = _controller.currentState;
    });
    _controller.initialize();
  }

  AppController get controller => _controller;

  /// Handle login success
  Future<void> onLoginSuccess() async {
    await _controller.onLoginSuccess();
  }

  /// Handle payment success
  Future<void> onPaymentSuccess() async {
    await _controller.onPaymentSuccess();
  }

  /// Handle logout
  void logout() {
    _controller.logout();
  }

  /// Reinitialize (useful for pull-to-refresh)
  Future<void> reinitialize() async {
    await _controller.initialize();
  }
}
