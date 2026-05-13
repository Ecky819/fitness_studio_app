import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../providers/analytics_providers.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/analytics_widgets.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(dailyUsageProvider);
    final peaksAsync = ref.watch(peakHoursProvider);
    final revenueAsync = ref.watch(revenueProvider);
    final activeUsersAsync = ref.watch(activeUsersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Analytics',
          subtitle: 'Usage trends, peak hours, and revenue insights',
          action: IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(dailyUsageProvider);
              ref.invalidate(peakHoursProvider);
              ref.invalidate(revenueProvider);
              ref.invalidate(activeUsersProvider);
            },
          ),
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
                // ── KPI Cards ──────────────────────────────────────────
                activeUsersAsync.when(
                  data: (data) => AnalyticsKpiRow(data: data),
                  loading: () => const _LoadingCard(height: 100),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Daily Usage Line Chart ─────────────────────────────
                usageAsync.when(
                  data: (data) => UsageLineChart(data: data),
                  loading: () => const _LoadingCard(height: 280),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Peak Hours Bar Chart ───────────────────────────────
                peaksAsync.when(
                  data: (data) => PeaksBarChart(hours: data),
                  loading: () => const _LoadingCard(height: 280),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Revenue Bar Chart ──────────────────────────────────
                revenueAsync.when(
                  data: (data) => RevenueBarChart(data: data),
                  loading: () => const _LoadingCard(height: 280),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) => AdminCard(
        child: SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
          ],
        ),
      );
}
