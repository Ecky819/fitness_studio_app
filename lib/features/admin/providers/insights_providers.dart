import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_service.dart';
import '../../../core/services/occupancy_websocket.dart';
import '../../../features/tenant/providers/tenant_provider.dart';

// ── Occupancy ──────────────────────────────────────────────────────────────

class OccupancyData {
  final int count;
  final int capacity;
  final int percentage;
  final String updatedAt;

  const OccupancyData({
    required this.count,
    required this.capacity,
    required this.percentage,
    required this.updatedAt,
  });

  factory OccupancyData.fromJson(Map<String, dynamic> json) => OccupancyData(
        count: json['count'] as int? ?? 0,
        capacity: json['capacity'] as int? ?? 50,
        percentage: json['percentage'] as int? ?? 0,
        updatedAt: json['updatedAt'] as String? ?? '',
      );

  OccupancyData copyWith({int? count, int? percentage}) => OccupancyData(
        count: count ?? this.count,
        capacity: capacity,
        percentage: percentage ?? this.percentage,
        updatedAt: DateTime.now().toIso8601String(),
      );
}

final occupancyProvider =
    StateNotifierProvider.autoDispose<OccupancyNotifier, AsyncValue<OccupancyData>>(
  (ref) {
    final config = ref.watch(tenantConfigSyncProvider);
    return OccupancyNotifier(config.tenantId);
  },
);

class OccupancyNotifier extends StateNotifier<AsyncValue<OccupancyData>> {
  OccupancyNotifier(this.tenantId) : super(const AsyncLoading()) {
    _init();
  }

  final String tenantId;
  OccupancyWebSocket? _socket;

  Future<void> _init() async {
    try {
      final data = await ApiService.getOccupancyCurrent();
      if (mounted) state = AsyncData(OccupancyData.fromJson(data));
    } catch (e) {
      if (mounted) state = AsyncError(e, StackTrace.current);
    }

    // Subscribe to real-time updates
    _socket = await createOccupancySocket(tenantId);
    _socket?.stream.listen((update) {
      if (!mounted) return;
      state.whenData((current) {
        final newPct = (update.count / current.capacity * 100).round();
        state = AsyncData(current.copyWith(count: update.count, percentage: newPct));
      });
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    super.dispose();
  }
}

// ── Churn Risk ─────────────────────────────────────────────────────────────

class ChurnRiskEntry {
  final String userId;
  final String email;
  final int churnScore;
  final String riskLevel;
  final String recommendation;
  final List<Map<String, dynamic>> factors;

  const ChurnRiskEntry({
    required this.userId,
    required this.email,
    required this.churnScore,
    required this.riskLevel,
    required this.recommendation,
    required this.factors,
  });

  factory ChurnRiskEntry.fromJson(Map<String, dynamic> json) => ChurnRiskEntry(
        userId: json['userId'] as String,
        email: json['email'] as String,
        churnScore: json['churnScore'] as int,
        riskLevel: json['riskLevel'] as String,
        recommendation: json['recommendation'] as String? ?? '',
        factors: ((json['factors'] as List?) ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList(),
      );
}

final churnRiskProvider = FutureProvider.autoDispose<List<ChurnRiskEntry>>((ref) async {
  final raw = await ApiService.getChurnRisk(limit: 50);
  return raw.map((e) => ChurnRiskEntry.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Anomalies ──────────────────────────────────────────────────────────────

class AnomalyEntry {
  final String type;
  final String userId;
  final String doorId;
  final int count;
  final int windowMinutes;

  const AnomalyEntry({
    required this.type,
    required this.userId,
    required this.doorId,
    required this.count,
    required this.windowMinutes,
  });

  factory AnomalyEntry.fromJson(Map<String, dynamic> json) => AnomalyEntry(
        type: json['type'] as String,
        userId: json['userId'] as String,
        doorId: json['doorId'] as String,
        count: json['count'] as int,
        windowMinutes: json['windowMinutes'] as int,
      );
}

final anomaliesProvider = FutureProvider.autoDispose<List<AnomalyEntry>>((ref) async {
  final raw = await ApiService.getAnomalies();
  return raw.map((e) => AnomalyEntry.fromJson(e as Map<String, dynamic>)).toList();
});
