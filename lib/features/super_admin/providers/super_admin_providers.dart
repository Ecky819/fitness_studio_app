import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_service.dart';
import '../models/tenant_summary.dart';

final platformStatsProvider = FutureProvider.autoDispose<PlatformStats>((ref) async {
  final data = await ApiService.getSuperAdminStats();
  return PlatformStats.fromJson(data);
});

final tenantsProvider =
    FutureProvider.autoDispose<List<TenantSummary>>((ref) async {
  final data = await ApiService.getSuperAdminTenants(limit: 50);
  final list = data['data'] as List? ?? [];
  return list
      .map((e) => TenantSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

class TenantsNotifier extends AsyncNotifier<List<TenantSummary>> {
  @override
  Future<List<TenantSummary>> build() => _fetch();

  Future<List<TenantSummary>> _fetch({String? search}) async {
    final data = await ApiService.getSuperAdminTenants(search: search);
    final list = data['data'] as List? ?? [];
    return list
        .map((e) => TenantSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> search(String q) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(search: q));
  }

  Future<void> updatePlan(String tenantId, String plan) async {
    await ApiService.updateTenantPlan(tenantId, plan);
    ref.invalidateSelf();
  }

  Future<void> updateStatus(String tenantId, String status) async {
    await ApiService.updateTenantStatus(tenantId, status);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final tenantsNotifierProvider =
    AsyncNotifierProvider<TenantsNotifier, List<TenantSummary>>(
  TenantsNotifier.new,
);
