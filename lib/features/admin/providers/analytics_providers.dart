import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_service.dart';
import '../models/analytics_models.dart';

// ── Individual providers (kept for invalidation in the refresh button) ─────────

final dailyUsageProvider =
    FutureProvider.autoDispose<List<DailyUsagePoint>>((ref) async {
  final raw = await ApiService.getAnalyticsUsage();
  return raw
      .map((e) => DailyUsagePoint.fromJson(e as Map<String, dynamic>))
      .toList();
});

final peakHoursProvider =
    FutureProvider.autoDispose<List<PeakHour>>((ref) async {
  final raw = await ApiService.getAnalyticsPeaks();
  return raw
      .map((e) => PeakHour.fromJson(e as Map<String, dynamic>))
      .toList();
});

final revenueProvider =
    FutureProvider.autoDispose<RevenueData>((ref) async {
  final data = await ApiService.getAnalyticsRevenue();
  return RevenueData.fromJson(data);
});

final activeUsersProvider =
    FutureProvider.autoDispose<ActiveUsersData>((ref) async {
  final data = await ApiService.getAnalyticsActiveUsers();
  return ActiveUsersData.fromJson(data);
});

// ── Combined bundle ────────────────────────────────────────────────────────────

class AnalyticsBundle {
  final List<DailyUsagePoint> usage;
  final List<PeakHour> peaks;
  final RevenueData revenue;
  final ActiveUsersData activeUsers;

  const AnalyticsBundle({
    required this.usage,
    required this.peaks,
    required this.revenue,
    required this.activeUsers,
  });
}

/// Combines all four analytics streams into a single AsyncValue so the page
/// shows one loading skeleton instead of four independent spinners.
///
/// Becomes [AsyncLoading] until every dataset is ready.
/// Becomes [AsyncError] with the first error that occurs.
final analyticsProvider =
    Provider.autoDispose<AsyncValue<AnalyticsBundle>>((ref) {
  final usage = ref.watch(dailyUsageProvider);
  final peaks = ref.watch(peakHoursProvider);
  final revenue = ref.watch(revenueProvider);
  final activeUsers = ref.watch(activeUsersProvider);

  // Propagate first error immediately.
  for (final v in [usage, peaks, revenue, activeUsers]) {
    if (v is AsyncError) {
      return AsyncError<AnalyticsBundle>(
        v.error ?? 'Unknown error',
        v.stackTrace ?? StackTrace.current,
      );
    }
  }

  // Stay in loading until every dataset has resolved.
  if ([usage, peaks, revenue, activeUsers].any((v) => v is AsyncLoading)) {
    return const AsyncLoading();
  }

  return AsyncData(AnalyticsBundle(
    usage: usage.requireValue,
    peaks: peaks.requireValue,
    revenue: revenue.requireValue,
    activeUsers: activeUsers.requireValue,
  ));
});
