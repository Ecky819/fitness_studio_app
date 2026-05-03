import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QrTokenProvider extends StateNotifier<String?> {
  QrTokenProvider() : super(null) {
    _startTokenRefresh();
  }

  Timer? _refreshTimer;
  static const refreshInterval = Duration(seconds: 30);

  Future<void> fetchToken(String doorId) async {
    try {
      // TODO: Replace with actual API endpoint
      final response = await http.get(
        Uri.parse('https://your-api.com/access/token?doorId=$doorId'),
        headers: {
          'Authorization': 'Bearer your-auth-token', // TODO: Add proper auth
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        state = data['token'] as String;
      } else {
        throw Exception('Failed to fetch token');
      }
    } catch (e) {
      print('Error fetching QR token: $e');
      // Keep existing token if available, or set to null
      if (state == null) {
        state = 'error'; // Placeholder for error state
      }
    }
  }

  void _startTokenRefresh() {
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      // Only refresh if we have a doorId context
      // This will be called when the provider is used with a doorId
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

// Provider for token with doorId parameter
final qrTokenForDoorProvider = FutureProvider.family<String?, String>((
  ref,
  doorId,
) async {
  final tokenProvider = ref.watch(qrTokenProvider.notifier);
  await tokenProvider.fetchToken(doorId);
  return ref.watch(qrTokenProvider);
});
