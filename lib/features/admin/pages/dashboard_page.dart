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
                  data: (logs) =>
                      _RecentLogsTable(logs: logs.take(10).toList()),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Total Users',
            value: '${stats.totalUsers}',
            icon: Icons.people_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'Active Members',
            value: '${stats.activeSubscriptions}',
            icon: Icons.verified_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'Devices Online',
            value: '${stats.devicesOnline}/${stats.totalDevices}',
            icon: Icons.sensors_rounded,
            color: AppColors.info,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'Access Today',
            value: '${stats.todayAccessCount}',
            icon: Icons.check_circle_rounded,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'Denied Today',
            value: '${stats.failedAccessToday}',
            icon: Icons.cancel_rounded,
            color: AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _RecentLogsTable extends StatelessWidget {
  final List<AccessLog> logs;
  const _RecentLogsTable({required this.logs});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            AppColors.surfaceVariant,
          ),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppColors.overlayHover;
            }
            return Colors.transparent;
          }),
          dividerThickness: 1,
          headingTextStyle:
              AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
          dataTextStyle: AppTextStyles.body,
          columns: const [
            DataColumn(label: Text('Timestamp')),
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Door')),
            DataColumn(label: Text('Result')),
            DataColumn(label: Text('Reason')),
          ],
          rows: logs.map((log) {
            return DataRow(cells: [
              DataCell(Text(
                formatTimestamp(log.timestamp),
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              )),
              DataCell(Text(log.userName)),
              DataCell(Text(log.deviceName)),
              DataCell(ResultBadge(granted: log.granted)),
              DataCell(Text(
                log.reason,
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
