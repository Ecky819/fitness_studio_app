import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    final logsAsync = ref.watch(logsNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Dashboard',
          subtitle: 'System overview and recent activity',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statsAsync.when(
                  loading: () => const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text(
                    'Stats error: $e',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  data: (stats) => _StatsRow(stats: stats),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Recent Access Events', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.md),
                logsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Logs error: $e',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  data: (logs) => AdminCard(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: AccessLogDataTable(logs: logs.take(10).toList()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final AdminStats stats;
  const _StatsRow({required this.stats});

  List<Widget> _cards(AdminStats s) => [
        StatCard(
          label: 'Total Users',
          value: '${s.totalUsers}',
          icon: Icons.people_rounded,
          color: AppColors.primary,
        ),
        StatCard(
          label: 'Active Members',
          value: '${s.activeSubscriptions}',
          icon: Icons.verified_rounded,
          color: AppColors.success,
        ),
        StatCard(
          label: 'Devices Online',
          value: '${s.devicesOnline}/${s.totalDevices}',
          icon: Icons.sensors_rounded,
          color: AppColors.info,
        ),
        StatCard(
          label: 'Access Today',
          value: '${s.todayAccessCount}',
          icon: Icons.check_circle_rounded,
          color: AppColors.warning,
        ),
        StatCard(
          label: 'Denied Today',
          value: '${s.failedAccessToday}',
          icon: Icons.cancel_rounded,
          color: AppColors.error,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        // ≥ 800px → 5 cards in one row (desktop / admin web)
        // 500–799px → 3 + 2
        // < 500px  → 2 + 2 + 1 (narrow mobile)
        final cols = w >= 800 ? 5 : w >= 500 ? 3 : 2;
        final cardWidth =
            (w - (cols - 1) * AppSpacing.md) / cols;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: _cards(stats)
              .map((c) => SizedBox(width: cardWidth, child: c))
              .toList(),
        );
      },
    );
  }
}
