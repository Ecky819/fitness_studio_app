import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_service.dart';
import '../models/admin_models.dart';

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
    final list = data['data'] as List? ?? (data.containsKey('data') ? [] : [data]);

    // API returns array directly or wrapped in data key
    final rawList = data.values.first is List
        ? data.values.first as List
        : [data];

    return (rawList).map((e) {
      final u = e as Map<String, dynamic>;
      final membership = u['membership'] as Map<String, dynamic>?;
      return AdminUser(
        id: u['id'] as String,
        name: u['email'] as String, // backend returns email, name not stored yet
        email: u['email'] as String,
        membershipStatus: _parseMembershipStatus(
          membership?['status'] as String?,
        ),
        plan: membership?['plan'] as String? ?? '—',
        validUntil: membership != null
            ? DateTime.tryParse(membership['validUntil'] as String? ?? '') ??
                DateTime.now()
            : DateTime.now(),
        isBlocked: u['isBlocked'] as bool? ?? false,
        createdAt: DateTime.tryParse(u['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();
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
