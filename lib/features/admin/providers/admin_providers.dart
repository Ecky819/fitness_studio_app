import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_service.dart';
import '../models/admin_models.dart';

// ── Profile ────────────────────────────────────────────────────────────────

final adminProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ApiService.getProfile();
});

// ── Stats ──────────────────────────────────────────────────────────────────

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final data = await ApiService.getAdminStats();
  return AdminStats(
    totalUsers: data['totalUsers'] as int? ?? 0,
    activeSubscriptions: data['activeSubscriptions'] as int? ?? 0,
    devicesOnline: data['onlineDevices'] as int? ?? 0,
    totalDevices: data['totalDevices'] as int? ?? 0,
    todayAccessCount: data['todayGranted'] as int? ?? 0,
    failedAccessToday: data['todayDenied'] as int? ?? 0,
  );
});

// ── Users ──────────────────────────────────────────────────────────────────

class UsersState {
  final List<AdminUser> users;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const UsersState({
    this.users = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  UsersState copyWith({
    List<AdminUser>? users,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) =>
      UsersState(
        users: users ?? this.users,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        searchQuery: searchQuery ?? this.searchQuery,
      );
}

class UsersNotifier extends AsyncNotifier<List<AdminUser>> {
  @override
  Future<List<AdminUser>> build() => _fetchUsers();

  Future<List<AdminUser>> _fetchUsers({String? search}) async {
    final data = await ApiService.getAdminUsers(search: search);

    final rawList = data['data'] as List? ?? [];

    return (rawList).map((e) {
      final u = e as Map<String, dynamic>;
      final membership = u['membership'] as Map<String, dynamic>?;
      return AdminUser(
        id: _safeString(u['id']),
        name: _safeString(u['name'], _safeString(u['email'])),
        email: _safeString(u['email']),
        membershipStatus: _parseMembershipStatus(
          _safeStringOrNull(membership?['status']),
        ),
        plan: _extractPlanName(membership?['plan']),
        validUntil: membership != null
            ? DateTime.tryParse(_safeString(membership['validUntil'])) ??
                DateTime.now()
            : DateTime.now(),
        isBlocked: u['isBlocked'] as bool? ?? false,
        createdAt: DateTime.tryParse(_safeString(u['createdAt'])) ??
            DateTime.now(),
      );
    }).toList();
  }

  String _safeString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is String) return value;
    if (value is List) {
      final joined = value.whereType<String>().join(' ').trim();
      return joined.isEmpty ? fallback : joined;
    }
    return value.toString();
  }

  String? _safeStringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      final strings = value.whereType<String>();
      return strings.isEmpty ? null : strings.first;
    }
    return value.toString();
  }

  Future<void> search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchUsers(search: query));
  }

  Future<void> toggleBlock(String userId) async {
    await ApiService.toggleUserBlock(userId);
    // Refresh list after toggle
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchUsers);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchUsers);
  }

  String _extractPlanName(dynamic plan) {
    if (plan == null) return '—';
    if (plan is String) return plan.isEmpty ? '—' : plan;
    if (plan is Map) return plan['name'] as String? ?? '—';
    if (plan is List && plan.isNotEmpty) {
      final first = plan.first;
      return first is Map ? first['name'] as String? ?? '—' : first.toString();
    }
    return '—';
  }

  MembershipStatus _parseMembershipStatus(String? status) {
    switch (status) {
      case 'ACTIVE':
        return MembershipStatus.active;
      case 'PAST_DUE':
        return MembershipStatus.pastDue;
      case 'CANCELED':
        return MembershipStatus.canceled;
      default:
        return MembershipStatus.expired;
    }
  }
}

final usersNotifierProvider =
    AsyncNotifierProvider<UsersNotifier, List<AdminUser>>(UsersNotifier.new);

// ── Devices ────────────────────────────────────────────────────────────────

final devicesProvider = FutureProvider.autoDispose<List<Device>>((ref) async {
  final data = await ApiService.getAdminDevices();
  final list = data['data'] as List? ?? [];
  return list.map((e) {
    final d = e as Map<String, dynamic>;
    return Device(
      id: d['id'] as String,
      name: d['name'] as String,
      location: d['location'] as String,
      isOnline: d['isOnline'] as bool? ?? false,
      lastActivity: DateTime.tryParse(d['lastSeenAt'] as String? ?? '') ??
          DateTime.now(),
      firmwareVersion: d['firmwareVersion'] as String? ?? '—',
      accessCount: 0, // not returned by current backend endpoint
    );
  }).toList();
});

// ── Logs ───────────────────────────────────────────────────────────────────

class LogFilter {
  final String userSearch;
  final String? doorId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const LogFilter({
    this.userSearch = '',
    this.doorId,
    this.dateFrom,
    this.dateTo,
  });

  static const _unset = Object();

  LogFilter copyWith({
    String? userSearch,
    Object? doorId = _unset,
    Object? dateFrom = _unset,
    Object? dateTo = _unset,
  }) =>
      LogFilter(
        userSearch: userSearch ?? this.userSearch,
        doorId: identical(doorId, _unset) ? this.doorId : doorId as String?,
        dateFrom: identical(dateFrom, _unset)
            ? this.dateFrom
            : dateFrom as DateTime?,
        dateTo:
            identical(dateTo, _unset) ? this.dateTo : dateTo as DateTime?,
      );
}

class LogsNotifier extends AsyncNotifier<List<AccessLog>> {
  LogFilter _filter = const LogFilter();

  @override
  Future<List<AccessLog>> build() => _fetchLogs();

  Future<List<AccessLog>> _fetchLogs() async {
    final data = await ApiService.getAdminLogs(
      doorId: _filter.doorId,
      dateFrom: _filter.dateFrom?.toIso8601String().split('T').first,
      dateTo: _filter.dateTo?.toIso8601String().split('T').first,
    );
    final list = data['data'] as List? ?? [];
    return list.map((e) {
      final l = e as Map<String, dynamic>;
      return AccessLog(
        id: l['id'] as String,
        userId: l['userId'] as String,
        userName: l['userEmail'] as String? ?? l['userId'] as String,
        deviceId: l['doorId'] as String? ?? '',
        deviceName: l['doorId'] as String? ?? 'Unknown Door',
        timestamp:
            DateTime.tryParse(l['timestamp'] as String? ?? '') ?? DateTime.now(),
        granted: l['status'] == 'GRANTED',
        reason: l['reason'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> applyFilter(LogFilter filter) async {
    _filter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchLogs);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchLogs);
  }
}

final logsNotifierProvider =
    AsyncNotifierProvider<LogsNotifier, List<AccessLog>>(LogsNotifier.new);

final logFilterProvider = StateProvider<LogFilter>((_) => const LogFilter());
