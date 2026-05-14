import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';

class QrTokenProvider extends StateNotifier<String?> {
  QrTokenProvider() : super(null);

  Timer? _refreshTimer;
  static const refreshInterval = Duration(seconds: 30);

  Future<void> fetchToken(String doorId) async {
    try {
      final data = await ApiService.fetchDoorAccessToken(doorId);
      if (mounted) state = data['token'] as String?;
    } catch (e) {
      debugPrint('Error fetching QR token: $e');
      if (mounted && state == null) state = null;
    }
  }

  void startAutoRefresh(String doorId) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      if (mounted) fetchToken(doorId);
    });
  }

  void stopRefresh() {
    _refreshTimer?.cancel();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final qrTokenProvider = StateNotifierProvider<QrTokenProvider, String?>((ref) {
  return QrTokenProvider();
});

// Provider for token with doorId parameter — fetches once, then auto-refreshes.
final qrTokenForDoorProvider = FutureProvider.family<String?, String>((
  ref,
  doorId,
) async {
  final notifier = ref.watch(qrTokenProvider.notifier);
  await notifier.fetchToken(doorId);
  notifier.startAutoRefresh(doorId);
  ref.onDispose(notifier.stopRefresh);
  return ref.read(qrTokenProvider);
});
