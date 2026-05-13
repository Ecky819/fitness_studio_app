class TenantSummary {
  final String id;
  final String name;
  final String slug;
  final String plan;
  final String status;
  final int userCount;
  final DateTime createdAt;
  final String? gymName;

  const TenantSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.plan,
    required this.status,
    required this.userCount,
    required this.createdAt,
    this.gymName,
  });

  factory TenantSummary.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    final config = json['config'] as Map<String, dynamic>?;
    return TenantSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      plan: json['plan'] as String? ?? 'STARTER',
      status: json['status'] as String? ?? 'TRIAL',
      userCount: count?['users'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      gymName: config?['gymName'] as String?,
    );
  }
}

class PlatformStats {
  final int totalTenants;
  final List<({String plan, int count})> byPlan;
  final List<({String status, int count})> byStatus;

  const PlatformStats({
    required this.totalTenants,
    required this.byPlan,
    required this.byStatus,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> json) => PlatformStats(
        totalTenants: json['totalTenants'] as int? ?? 0,
        byPlan: ((json['byPlan'] as List?) ?? [])
            .map((e) => (plan: e['plan'] as String, count: e['count'] as int))
            .toList(),
        byStatus: ((json['byStatus'] as List?) ?? [])
            .map((e) => (status: e['status'] as String, count: e['count'] as int))
            .toList(),
      );
}
