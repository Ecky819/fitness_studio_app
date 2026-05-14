import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../models/analytics_models.dart';
import 'admin_widgets.dart';

// ── KPI Cards ──────────────────────────────────────────────────────────────

class AnalyticsKpiRow extends StatelessWidget {
  final ActiveUsersData data;
  const AnalyticsKpiRow({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Total Users',
            value: '${data.totalUsers}',
            icon: Icons.people_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'Active Members',
            value: '${data.activeSubscriptions}',
            icon: Icons.verified_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'New This Month',
            value: '+${data.newUsersThisMonth}',
            icon: Icons.person_add_rounded,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'Active (30d)',
            value: '${data.activeUsersLast30Days}',
            icon: Icons.directions_run_rounded,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

// ── Usage Line Chart ───────────────────────────────────────────────────────

class UsageLineChart extends StatelessWidget {
  final List<DailyUsagePoint> data;
  const UsageLineChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart(label: 'No usage data');

    final maxY = data
            .map((d) => d.granted + d.denied)
            .fold<int>(0, (a, b) => a > b ? a : b)
            .toDouble() *
        1.2;

    return AdminCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ChartHeader(
            title: 'Daily Access Events',
            subtitle: 'Last 30 days',
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              _Legend(color: AppColors.primary, label: 'Granted'),
              SizedBox(width: AppSpacing.lg),
              _Legend(color: AppColors.error, label: 'Denied'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  _buildLine(
                    spots: data
                        .asMap()
                        .entries
                        .map((e) => FlSpot(
                            e.key.toDouble(), e.value.granted.toDouble()))
                        .toList(),
                    color: AppColors.primary,
                  ),
                  _buildLine(
                    spots: data
                        .asMap()
                        .entries
                        .map((e) =>
                            FlSpot(e.key.toDouble(), e.value.denied.toDouble()))
                        .toList(),
                    color: AppColors.error,
                  ),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (data.length / 5).ceilToDouble(),
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        final parts = data[idx].date.split('-');
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${parts[2]}.${parts[1]}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceVariant,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              s.y.toInt().toString(),
                              AppTextStyles.caption.copyWith(
                                color: s.bar.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine({
    required List<FlSpot> spots,
    required Color color,
  }) =>
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withValues(alpha: 0.08),
        ),
      );
}

// ── Peak Hours Bar Chart ───────────────────────────────────────────────────

class PeaksBarChart extends StatelessWidget {
  final List<PeakHour> hours;
  const PeaksBarChart({super.key, required this.hours});

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) return const _EmptyChart(label: 'No peak data');

    final maxCount = hours
        .map((h) => h.count)
        .fold<int>(1, (a, b) => a > b ? a : b)
        .toDouble();

    return AdminCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ChartHeader(
            title: 'Peak Hours',
            subtitle: 'Granted access by hour of day',
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxCount * 1.2,
                barGroups: hours.map((h) {
                  final ratio = maxCount > 0 ? h.count / maxCount : 0.0;
                  final isHigh = ratio > 0.7;
                  final isMid = ratio > 0.4;
                  final color = isHigh
                      ? AppColors.primary
                      : isMid
                          ? AppColors.info
                          : AppColors.primary.withValues(alpha: 0.3);

                  return BarChartGroupData(
                    x: h.hour,
                    barRods: [
                      BarChartRodData(
                        toY: h.count.toDouble(),
                        color: color,
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        final h = value.toInt();
                        if (h % 6 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${h.toString().padLeft(2, '0')}h',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceVariant,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${group.x}h: ${rod.toY.toInt()}',
                      AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Revenue Bar Chart ──────────────────────────────────────────────────────

class RevenueBarChart extends StatelessWidget {
  final RevenueData data;
  const RevenueBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.monthly.isEmpty) {
      return const _EmptyChart(label: 'No revenue data');
    }

    final maxY = data.monthly
            .map((m) => m.totalEuros)
            .fold<double>(1, (a, b) => a > b ? a : b) *
        1.2;

    return AdminCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: _ChartHeader(
                  title: 'Monthly Revenue',
                  subtitle: 'Succeeded payments',
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '€${data.totalEuros.toStringAsFixed(2)}',
                    style: AppTextStyles.h3.copyWith(color: AppColors.success),
                  ),
                  Text(
                    '${data.totalPayments} payments',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barGroups: data.monthly.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.totalEuros,
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [AppColors.success, AppColors.primary],
                        ),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.monthly.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data.monthly[idx].shortMonth,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, _) => Text(
                        '€${value.toInt()}',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceVariant,
                    getTooltipItem: (group, _, rod, __) {
                      final idx = group.x;
                      if (idx < 0 || idx >= data.monthly.length) return null;
                      final m = data.monthly[idx];
                      return BarTooltipItem(
                        '${m.shortMonth}\n€${m.totalEuros.toStringAsFixed(2)}',
                        AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared internals ───────────────────────────────────────────────────────

class _ChartHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ChartHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
        ],
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      );
}

class _EmptyChart extends StatelessWidget {
  final String label;
  const _EmptyChart({required this.label});

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
          ),
        ),
      );
}
