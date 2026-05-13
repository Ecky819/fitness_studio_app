import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_controller.dart';

final appControllerProvider =
    StateNotifierProvider<AppControllerNotifier, AppState>((ref) {
  return AppControllerNotifier();
});

class AppControllerNotifier extends StateNotifier<AppState> {
  final AppController _controller = AppController();

  AppControllerNotifier() : super(AppState.loading) {
    _controller.addListener(() => state = _controller.currentState);
    _controller.initialize();
  }

  Future<void> onLoginSuccess() => _controller.onLoginSuccess();
  Future<void> onPaymentSuccess() => _controller.onPaymentSuccess();
  Future<void> logout() => _controller.logout();
  Future<void> reinitialize() => _controller.initialize();
}
