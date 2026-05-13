class DailyUsagePoint {
  final String date; // 'YYYY-MM-DD'
  final int granted;
  final int denied;

  const DailyUsagePoint({
    required this.date,
    required this.granted,
    required this.denied,
  });

  factory DailyUsagePoint.fromJson(Map<String, dynamic> json) =>
      DailyUsagePoint(
        date: json['date'] as String,
        granted: json['granted'] as int,
        denied: json['denied'] as int,
      );

  int get total => granted + denied;
}

class PeakHour {
  final int hour;
  final int count;

  const PeakHour({required this.hour, required this.count});

  factory PeakHour.fromJson(Map<String, dynamic> json) => PeakHour(
        hour: json['hour'] as int,
        count: json['count'] as int,
      );

  String get label {
    final h = hour.toString().padLeft(2, '0');
    return '${h}h';
  }
}

class MonthlyRevenue {
  final String month; // 'YYYY-MM'
  final int totalCents;
  final int count;

  const MonthlyRevenue({
    required this.month,
    required this.totalCents,
    required this.count,
  });

  factory MonthlyRevenue.fromJson(Map<String, dynamic> json) => MonthlyRevenue(
        month: json['month'] as String,
        totalCents: json['totalCents'] as int,
        count: json['count'] as int,
      );

  double get totalEuros => totalCents / 100.0;

  String get shortMonth {
    final parts = month.split('-');
    if (parts.length < 2) return month;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    return months[m];
  }
}

class RevenueData {
  final List<MonthlyRevenue> monthly;
  final int totalCents;
  final int totalPayments;

  const RevenueData({
    required this.monthly,
    required this.totalCents,
    required this.totalPayments,
  });

  double get totalEuros => totalCents / 100.0;

  factory RevenueData.fromJson(Map<String, dynamic> json) => RevenueData(
        monthly: (json['monthly'] as List)
            .map((e) => MonthlyRevenue.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalCents: json['totalCents'] as int,
        totalPayments: json['totalPayments'] as int,
      );
}

class ActiveUsersData {
  final int totalUsers;
  final int activeSubscriptions;
  final int newUsersThisMonth;
  final int activeUsersLast30Days;

  const ActiveUsersData({
    required this.totalUsers,
    required this.activeSubscriptions,
    required this.newUsersThisMonth,
    required this.activeUsersLast30Days,
  });

  factory ActiveUsersData.fromJson(Map<String, dynamic> json) =>
      ActiveUsersData(
        totalUsers: json['totalUsers'] as int,
        activeSubscriptions: json['activeSubscriptions'] as int,
        newUsersThisMonth: json['newUsersThisMonth'] as int,
        activeUsersLast30Days: json['activeUsersLast30Days'] as int,
      );
}
