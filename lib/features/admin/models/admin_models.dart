enum MembershipStatus { active, expired, canceled, pastDue }

class AdminUser {
  final String id;
  final String name;
  final String email;
  final MembershipStatus membershipStatus;
  final String plan;
  final DateTime validUntil;
  final bool isBlocked;
  final DateTime createdAt;

  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.membershipStatus,
    required this.plan,
    required this.validUntil,
    required this.isBlocked,
    required this.createdAt,
  });

  AdminUser copyWith({bool? isBlocked}) => AdminUser(
        id: id,
        name: name,
        email: email,
        membershipStatus: membershipStatus,
        plan: plan,
        validUntil: validUntil,
        isBlocked: isBlocked ?? this.isBlocked,
        createdAt: createdAt,
      );
}

class Device {
  final String id;
  final String name;
  final String location;
  final bool isOnline;
  final DateTime lastActivity;
  final String firmwareVersion;
  final int accessCount;

  const Device({
    required this.id,
    required this.name,
    required this.location,
    required this.isOnline,
    required this.lastActivity,
    required this.firmwareVersion,
    required this.accessCount,
  });
}

class AccessLog {
  final String id;
  final String userId;
  final String userName;
  final String deviceId;
  final String deviceName;
  final DateTime timestamp;
  final bool granted;
  final String reason;

  const AccessLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
    required this.granted,
    required this.reason,
  });
}

class AdminStats {
  final int totalUsers;
  final int activeSubscriptions;
  final int devicesOnline;
  final int totalDevices;
  final int todayAccessCount;
  final int failedAccessToday;

  const AdminStats({
    required this.totalUsers,
    required this.activeSubscriptions,
    required this.devicesOnline,
    required this.totalDevices,
    required this.todayAccessCount,
    required this.failedAccessToday,
  });
}
