import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/admin_models.dart';

// ===== MOCK DATA =====

final _mockUsers = [
  AdminUser(
    id: 'u1',
    name: 'Max Mustermann',
    email: 'max.mustermann@example.com',
    membershipStatus: MembershipStatus.active,
    plan: 'Premium',
    validUntil: DateTime(2026, 6, 30),
    isBlocked: false,
    createdAt: DateTime(2025, 1, 15),
  ),
  AdminUser(
    id: 'u2',
    name: 'Anna Schmidt',
    email: 'anna.schmidt@example.com',
    membershipStatus: MembershipStatus.active,
    plan: 'Basic',
    validUntil: DateTime(2026, 5, 31),
    isBlocked: false,
    createdAt: DateTime(2025, 3, 1),
  ),
  AdminUser(
    id: 'u3',
    name: 'Tom Weber',
    email: 'tom.weber@example.com',
    membershipStatus: MembershipStatus.expired,
    plan: 'Premium',
    validUntil: DateTime(2026, 4, 1),
    isBlocked: false,
    createdAt: DateTime(2024, 11, 20),
  ),
  AdminUser(
    id: 'u4',
    name: 'Lisa König',
    email: 'lisa.koenig@example.com',
    membershipStatus: MembershipStatus.active,
    plan: 'Annual',
    validUntil: DateTime(2027, 1, 1),
    isBlocked: false,
    createdAt: DateTime(2026, 1, 1),
  ),
  AdminUser(
    id: 'u5',
    name: 'Hans Bauer',
    email: 'hans.bauer@example.com',
    membershipStatus: MembershipStatus.canceled,
    plan: 'Basic',
    validUntil: DateTime(2026, 3, 15),
    isBlocked: true,
    createdAt: DateTime(2024, 8, 10),
  ),
  AdminUser(
    id: 'u6',
    name: 'Maria Hoffmann',
    email: 'maria.hoffmann@example.com',
    membershipStatus: MembershipStatus.active,
    plan: 'Premium',
    validUntil: DateTime(2026, 7, 31),
    isBlocked: false,
    createdAt: DateTime(2025, 7, 1),
  ),
  AdminUser(
    id: 'u7',
    name: 'Klaus Fischer',
    email: 'k.fischer@example.com',
    membershipStatus: MembershipStatus.pastDue,
    plan: 'Annual',
    validUntil: DateTime(2026, 4, 30),
    isBlocked: false,
    createdAt: DateTime(2025, 4, 30),
  ),
  AdminUser(
    id: 'u8',
    name: 'Sophie Wagner',
    email: 'sophie.w@example.com',
    membershipStatus: MembershipStatus.active,
    plan: 'Premium',
    validUntil: DateTime(2026, 8, 1),
    isBlocked: false,
    createdAt: DateTime(2026, 2, 14),
  ),
];

final _mockDevices = [
  Device(
    id: 'd1',
    name: 'Main Entrance',
    location: 'Front Door',
    isOnline: true,
    lastActivity: DateTime.now().subtract(const Duration(minutes: 2)),
    firmwareVersion: 'v2.3.1',
    accessCount: 142,
  ),
  Device(
    id: 'd2',
    name: 'Side Door',
    location: 'Side Entrance',
    isOnline: true,
    lastActivity: DateTime.now().subtract(const Duration(minutes: 15)),
    firmwareVersion: 'v2.3.1',
    accessCount: 38,
  ),
  Device(
    id: 'd3',
    name: 'Gym Area',
    location: 'Ground Floor',
    isOnline: false,
    lastActivity: DateTime.now().subtract(const Duration(hours: 4)),
    firmwareVersion: 'v2.2.0',
    accessCount: 0,
  ),
  Device(
    id: 'd4',
    name: 'Locker Room',
    location: 'First Floor',
    isOnline: true,
    lastActivity: DateTime.now().subtract(const Duration(minutes: 5)),
    firmwareVersion: 'v2.3.1',
    accessCount: 87,
  ),
];

List<AccessLog> _buildMockLogs() {
  final now = DateTime.now();
  final users = [
    ('u1', 'Max Mustermann'),
    ('u2', 'Anna Schmidt'),
    ('u3', 'Tom Weber'),
    ('u4', 'Lisa König'),
    ('u6', 'Maria Hoffmann'),
    ('u8', 'Sophie Wagner'),
  ];
  final doors = [
    ('d1', 'Main Entrance'),
    ('d2', 'Side Door'),
    ('d4', 'Locker Room'),
  ];
  const grantedReasons = ['QR Token Valid', 'BLE Token Valid'];
  const deniedReasons = [
    'Membership Expired',
    'User Blocked',
    'Invalid Token',
    'Access Grant Revoked',
  ];

  return List.generate(50, (i) {
    final user = users[i % users.length];
    final door = doors[i % doors.length];
    final granted = i % 5 != 0;
    return AccessLog(
      id: 'log$i',
      userId: user.$1,
      userName: user.$2,
      deviceId: door.$1,
      deviceName: door.$2,
      timestamp: now.subtract(Duration(minutes: i * 18)),
      granted: granted,
      reason: granted
          ? grantedReasons[i % grantedReasons.length]
          : deniedReasons[i % deniedReasons.length],
    );
  });
}

final _mockLogs = _buildMockLogs();

// ===== USERS =====

class UsersNotifier extends StateNotifier<List<AdminUser>> {
  UsersNotifier() : super(_mockUsers);

  void toggleBlock(String userId) {
    state = state.map((u) {
      if (u.id != userId) return u;
      return u.copyWith(isBlocked: !u.isBlocked);
    }).toList();
  }
}

final usersNotifierProvider =
    StateNotifierProvider<UsersNotifier, List<AdminUser>>(
  (ref) => UsersNotifier(),
);

// ===== DEVICES =====

final devicesProvider = Provider<List<Device>>((ref) => _mockDevices);

// ===== STATS =====

final adminStatsProvider = Provider<AdminStats>((ref) {
  final users = ref.watch(usersNotifierProvider);
  final today = DateTime.now();

  final activeUsers = users
      .where((u) =>
          u.membershipStatus == MembershipStatus.active && !u.isBlocked)
      .length;

  final onlineDevices = _mockDevices.where((d) => d.isOnline).length;

  final todayLogs = _mockLogs.where((l) =>
      l.timestamp.year == today.year &&
      l.timestamp.month == today.month &&
      l.timestamp.day == today.day);

  return AdminStats(
    activeUsers: activeUsers,
    devicesOnline: onlineDevices,
    totalDevices: _mockDevices.length,
    todayAccessCount: todayLogs.where((l) => l.granted).length,
    failedAccessToday: todayLogs.where((l) => !l.granted).length,
  );
});

// ===== LOGS =====

final allLogsProvider = Provider<List<AccessLog>>((ref) => _mockLogs);

final recentLogsProvider = Provider<List<AccessLog>>(
  (ref) => ref.watch(allLogsProvider).take(10).toList(),
);

class LogFilterNotifier extends StateNotifier<LogFilter> {
  LogFilterNotifier() : super(const LogFilter());

  void setUserSearch(String search) {
    state = LogFilter(
      userSearch: search,
      deviceId: state.deviceId,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
    );
  }

  void setDeviceId(String? deviceId) {
    state = LogFilter(
      userSearch: state.userSearch,
      deviceId: deviceId,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
    );
  }

  void setDateFrom(DateTime? date) {
    state = LogFilter(
      userSearch: state.userSearch,
      deviceId: state.deviceId,
      dateFrom: date,
      dateTo: state.dateTo,
    );
  }

  void setDateTo(DateTime? date) {
    state = LogFilter(
      userSearch: state.userSearch,
      deviceId: state.deviceId,
      dateFrom: state.dateFrom,
      dateTo: date,
    );
  }

  void clearAll() => state = const LogFilter();
}

final logFilterProvider =
    StateNotifierProvider<LogFilterNotifier, LogFilter>(
  (ref) => LogFilterNotifier(),
);

final filteredLogsProvider = Provider<List<AccessLog>>((ref) {
  final logs = ref.watch(allLogsProvider);
  final filter = ref.watch(logFilterProvider);

  return logs.where((log) {
    if (filter.userSearch.isNotEmpty &&
        !log.userName.toLowerCase().contains(filter.userSearch.toLowerCase())) {
      return false;
    }
    if (filter.deviceId != null && log.deviceId != filter.deviceId) {
      return false;
    }
    if (filter.dateFrom != null && log.timestamp.isBefore(filter.dateFrom!)) {
      return false;
    }
    if (filter.dateTo != null) {
      final end = DateTime(
        filter.dateTo!.year,
        filter.dateTo!.month,
        filter.dateTo!.day,
        23,
        59,
        59,
      );
      if (log.timestamp.isAfter(end)) return false;
    }
    return true;
  }).toList();
});
