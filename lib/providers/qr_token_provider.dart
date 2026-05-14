import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';

// Each door gets its own isolated notifier — no shared state between doors.
class QrTokenNotifier extends StateNotifier<AsyncValue<String?>> {
  QrTokenNotifier(this.doorId) : super(const AsyncLoading()) {
    _fetch();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetch(),
    );
  }

  final String doorId;
  Timer? _refreshTimer;

  Future<void> _fetch() async {
    try {
      final data = await ApiService.fetchDoorAccessToken(doorId);
      if (mounted) state = AsyncData(data['token'] as String?);
    } catch (e, st) {
      debugPrint('QR token fetch failed for $doorId: $e');
      if (mounted) state = AsyncError(e, st);
    }
  }

  Future<void> refresh() => _fetch();

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final qrTokenForDoorProvider =
    StateNotifierProvider.family<QrTokenNotifier, AsyncValue<String?>, String>(
  (ref, doorId) => QrTokenNotifier(doorId),
);
