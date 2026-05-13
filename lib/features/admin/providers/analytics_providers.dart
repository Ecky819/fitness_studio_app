import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_service.dart';
import '../models/analytics_models.dart';

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
