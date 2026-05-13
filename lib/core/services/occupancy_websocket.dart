import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api_service.dart';

/// Streams real-time occupancy updates from the backend WebSocket gateway.
///
/// Usage:
///   final client = OccupancyWebSocket(tenantId: 'abc', jwtToken: '...');
///   client.stream.listen((update) => setState(() => count = update.count));
///   await client.connect();
///   // ...
///   client.disconnect();
class OccupancyUpdate {
  final String tenantId;
  final int count;
  final DateTime timestamp;

  const OccupancyUpdate({
    required this.tenantId,
    required this.count,
    required this.timestamp,
  });

  factory OccupancyUpdate.fromJson(Map<String, dynamic> json) =>
      OccupancyUpdate(
        tenantId: json['tenantId'] as String,
        count: json['count'] as int,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

class OccupancyWebSocket {
  static const String _baseWsUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:3000',
  );

  final String tenantId;
  final String jwtToken;

  WebSocketChannel? _channel;
  final _controller = StreamController<OccupancyUpdate>.broadcast();
  Timer? _reconnectTimer;
  bool _disposed = false;

  OccupancyWebSocket({required this.tenantId, required this.jwtToken});

  Stream<OccupancyUpdate> get stream => _controller.stream;

  Future<void> connect() async {
    if (_disposed) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$_baseWsUrl/ws/occupancy'),
      );

      // Authenticate immediately after connecting
      _channel!.sink.add(jsonEncode({'type': 'subscribe', 'token': jwtToken}));

      _channel!.stream.listen(
        (raw) {
          try {
            final msg = jsonDecode(raw as String) as Map<String, dynamic>;
            if (msg['type'] == 'occupancy_update') {
              _controller.add(OccupancyUpdate.fromJson(msg));
            }
          } catch (_) {}
        },
        onDone: () => _scheduleReconnect(),
        onError: (e) {
          if (kDebugMode) debugPrint('[OccupancyWS] Error: $e');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[OccupancyWS] Connect failed: $e');
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller.close();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () => connect());
  }
}

/// Convenience: creates a connected OccupancyWebSocket using stored JWT token.
Future<OccupancyWebSocket?> createOccupancySocket(String tenantId) async {
  final token = await ApiService.getAccessToken();
  if (token == null) return null;
  final socket = OccupancyWebSocket(tenantId: tenantId, jwtToken: token);
  await socket.connect();
  return socket;
}
