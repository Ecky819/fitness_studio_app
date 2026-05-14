import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../providers/analytics_providers.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/analytics_widgets.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(dailyUsageProvider);
    ref.invalidate(peakHoursProvider);
    ref.invalidate(revenueProvider);
    ref.invalidate(activeUsersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(analyticsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Analytics',
          subtitle: 'Usage trends, peak hours, and revenue insights',
          action: IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: () => _refresh(ref),
          ),
        ),
        Expanded(
          child: bundleAsync.when(
            loading: () => const _FullPageLoader(),
            error: (e, _) => _FullPageError(
              message: e.toString(),
              onRetry: () => _refresh(ref),
            ),
            data: (bundle) => _AnalyticsContent(bundle: bundle),
          ),
        ),
      ],
    );
  }
}

// ── Content ────────────────────────────────────────────────────────────────────

class _AnalyticsContent extends StatelessWidget {
  final AnalyticsBundle bundle;
  const _AnalyticsContent({required this.bundle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI Cards ────────────────────────────────────────────────
          AnalyticsKpiRow(data: bundle.activeUsers),
          const SizedBox(height: AppSpacing.xl),

          // ── Daily Usage ──────────────────────────────────────────────
          if (bundle.usage.isEmpty)
            const _EmptyDataCard(
              icon: Icons.show_chart_rounded,
              label: 'No usage data for this period',
            )
          else
            UsageLineChart(data: bundle.usage),
          const SizedBox(height: AppSpacing.xl),

          // ── Peak Hours ───────────────────────────────────────────────
          if (bundle.peaks.isEmpty)
            const _EmptyDataCard(
              icon: Icons.bar_chart_rounded,
              label: 'No peak-hour data available yet',
            )
          else
            PeaksBarChart(hours: bundle.peaks),
          const SizedBox(height: AppSpacing.xl),

          // ── Revenue ──────────────────────────────────────────────────
          if (bundle.revenue.monthly.isEmpty)
            const _EmptyDataCard(
              icon: Icons.euro_rounded,
              label: 'No revenue data recorded yet',
            )
          else
            RevenueBarChart(data: bundle.revenue),
        ],
      ),
    );
  }
}

// ── State widgets ─────────────────────────────────────────────────────────────

class _FullPageLoader extends StatelessWidget {
  const _FullPageLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _FullPageError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FullPageError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load analytics', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDataCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyDataCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
