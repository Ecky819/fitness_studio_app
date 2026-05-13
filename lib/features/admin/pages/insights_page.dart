import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../providers/insights_providers.dart';
import '../widgets/admin_widgets.dart';

/// AI Insights Dashboard — Occupancy, Churn Risk, and Anomaly Detection.
class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occupancyAsync = ref.watch(occupancyProvider);
    final churnAsync = ref.watch(churnRiskProvider);
    final anomaliesAsync = ref.watch(anomaliesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'AI Insights',
          subtitle: 'Occupancy, churn risk and anomaly detection',
          action: IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () {
              ref.invalidate(occupancyProvider);
              ref.invalidate(churnRiskProvider);
              ref.invalidate(anomaliesProvider);
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Live Occupancy ──────────────────────────────────────────
                occupancyAsync.when(
                  loading: () => const _LoadingCard(height: 120),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                  data: (data) => _OccupancyCard(data: data),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Anomalies ───────────────────────────────────────────────
                Text('Security Anomalies', style: AppTextStyles.h4),
                const SizedBox(height: 4),
                Text('Detected in the last 24 hours',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: AppSpacing.md),
                anomaliesAsync.when(
                  loading: () => const _LoadingCard(height: 80),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                  data: (anomalies) => anomalies.isEmpty
                      ? _EmptyCard(label: 'No anomalies detected — all clear')
                      : _AnomalyList(anomalies: anomalies),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Churn Risk ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Churn Risk', style: AppTextStyles.h4),
                      const SizedBox(height: 4),
                      Text('Top at-risk members (rule-based scoring)',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textTertiary)),
                    ]),
                    churnAsync.whenOrNull(
                      data: (list) {
                        final high =
                            list.where((e) => e.riskLevel == 'HIGH').length;
                        return high > 0
                            ? _RiskBadge(count: high, label: 'HIGH RISK')
                            : null;
                      },
                    ) ??
                        const SizedBox.shrink(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                churnAsync.when(
                  loading: () => const _LoadingCard(height: 200),
                  error: (e, _) => _ErrorCard(message: e.toString()),
                  data: (entries) => entries.isEmpty
                      ? _EmptyCard(label: 'No churn risk data yet')
                      : _ChurnTable(entries: entries),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Occupancy Card ─────────────────────────────────────────────────────────────

class _OccupancyCard extends StatelessWidget {
  final OccupancyData data;
  const _OccupancyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = data.percentage.clamp(0, 100);
    final color = pct >= 85
        ? AppColors.error
        : pct >= 60
            ? AppColors.warning
            : AppColors.success;

    return AdminCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(Icons.people_rounded, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Live Occupancy',
                style: AppTextStyles.h4),
            Text('Updates in real-time via WebSocket',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${data.count}/${data.capacity}',
                style: AppTextStyles.h2.copyWith(color: color)),
            Text('$pct% capacity',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary)),
          ]),
        ]),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          _CapacityLabel(pct: 0, label: 'Empty'),
          const Spacer(),
          _CapacityLabel(pct: 50, label: '50%'),
          const Spacer(),
          _CapacityLabel(pct: 100, label: 'Full'),
        ]),
      ]),
    );
  }
}

class _CapacityLabel extends StatelessWidget {
  final int pct;
  final String label;
  const _CapacityLabel({required this.pct, required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
      );
}

// ── Anomaly List ───────────────────────────────────────────────────────────────

class _AnomalyList extends StatelessWidget {
  final List<AnomalyEntry> anomalies;
  const _AnomalyList({required this.anomalies});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        children: anomalies.map((a) {
          final (icon, color, label) = switch (a.type) {
            'RAPID_RETRIES' => (
                Icons.warning_rounded,
                AppColors.error,
                'Rapid Retries'
              ),
            'OFF_HOURS_ACCESS' => (
                Icons.nightlight_round,
                AppColors.warning,
                'Off-Hours Access'
              ),
            _ => (Icons.info_rounded, AppColors.info, a.type),
          };
          return ListTile(
            leading: Icon(icon, color: color, size: 20),
            title: Text('$label — Door ${a.doorId}', style: AppTextStyles.body),
            subtitle: Text(
              '${a.count}× in ${a.windowMinutes}min | User: ${a.userId.substring(0, 8)}…',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(label,
                  style: AppTextStyles.caption.copyWith(color: color)),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Churn Risk Table ───────────────────────────────────────────────────────────

class _ChurnTable extends StatelessWidget {
  final List<ChurnRiskEntry> entries;
  const _ChurnTable({required this.entries});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
          headingTextStyle:
              AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
          dataTextStyle: AppTextStyles.body,
          columns: const [
            DataColumn(label: Text('Member')),
            DataColumn(label: Text('Score')),
            DataColumn(label: Text('Risk')),
            DataColumn(label: Text('Top Factor')),
            DataColumn(label: Text('Recommendation')),
          ],
          rows: entries.take(20).map((e) {
            final riskColor = switch (e.riskLevel) {
              'HIGH' => AppColors.error,
              'MEDIUM' => AppColors.warning,
              _ => AppColors.success,
            };
            final topFactor = e.factors.isNotEmpty
                ? (e.factors.first['detail'] as String? ?? '—')
                : '—';

            return DataRow(cells: [
              DataCell(Text(e.email)),
              DataCell(_ScoreBar(score: e.churnScore, color: riskColor)),
              DataCell(_RiskChip(level: e.riskLevel, color: riskColor)),
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(topFactor,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              )),
              DataCell(ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(e.recommendation,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final int score;
  final Color color;
  const _ScoreBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$score',
              style:
                  AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      );
}

class _RiskChip extends StatelessWidget {
  final String level;
  final Color color;
  const _RiskChip({required this.level, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(level,
            style:
                AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}

class _RiskBadge extends StatelessWidget {
  final int count;
  final String label;
  const _RiskBadge({required this.count, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_rounded, size: 14, color: AppColors.error),
          const SizedBox(width: 4),
          Text('$count $label',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) => AdminCard(
        child: SizedBox(
            height: height,
            child: const Center(child: CircularProgressIndicator())),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(message,
                  style: AppTextStyles.body.copyWith(color: AppColors.error))),
        ]),
      );
}

class _EmptyCard extends StatelessWidget {
  final String label;
  const _EmptyCard({required this.label});

  @override
  Widget build(BuildContext context) => AdminCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        ]),
      );
}
