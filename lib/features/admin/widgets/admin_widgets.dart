import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../models/admin_models.dart';

// ===== SHARED UTILITIES =====

String formatTimestamp(DateTime dt) {
  final d =
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  final t =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  return '$d  $t';
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

// ===== STAT CARD =====

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTextStyles.h2.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ===== ADMIN CARD =====

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AdminCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ===== RESULT BADGE =====

class ResultBadge extends StatelessWidget {
  final bool granted;

  const ResultBadge({super.key, required this.granted});

  @override
  Widget build(BuildContext context) {
    return _StatusChip(
      label: granted ? 'Granted' : 'Denied',
      color: granted ? AppColors.success : AppColors.error,
    );
  }
}

// ===== MEMBERSHIP STATUS BADGE =====

class MembershipBadge extends StatelessWidget {
  final String status;

  const MembershipBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => ('Active', AppColors.success),
      'expired' => ('Expired', AppColors.warning),
      'canceled' => ('Canceled', AppColors.error),
      'pastDue' => ('Past Due', AppColors.warning),
      _ => (status, AppColors.textTertiary),
    };
    return _StatusChip(label: label, color: color);
  }
}

// ===== ONLINE STATUS BADGE =====

class OnlineBadge extends StatelessWidget {
  final bool isOnline;

  const OnlineBadge({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOnline ? AppColors.success : AppColors.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isOnline ? 'Online' : 'Offline',
          style: AppTextStyles.body.copyWith(
            color: isOnline ? AppColors.success : AppColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ===== PAGE HEADER =====

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}

// ===== ASYNC PAGE SCAFFOLD =====

/// Wraps a FutureProvider / AsyncNotifierProvider result with a standard
/// loading skeleton and error view that matches the admin page layout.
class AsyncPageScaffold<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final String title;
  final Widget Function(T data) builder;

  const AsyncPageScaffold({
    super.key,
    required this.value,
    required this.title,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: title, subtitle: 'Loading…'),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: title, subtitle: '—'),
          Expanded(
            child: Center(
              child: Text(
                'Error: $e',
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
      data: builder,
    );
  }
}

// ===== ACCESS LOG DATA TABLE =====

/// Renders a styled DataTable of access log entries — shared between
/// DashboardPage (recent logs) and LogsPage (full list).
class AccessLogDataTable extends StatelessWidget {
  final List<AccessLog> logs;

  const AccessLogDataTable({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return AppColors.overlayHover;
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
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          )),
          DataCell(Text(log.userName)),
          DataCell(Text(log.deviceName)),
          DataCell(ResultBadge(granted: log.granted)),
          DataCell(Text(
            log.reason,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          )),
        ]);
      }).toList(),
    );
  }
}

// ===== INTERNAL =====

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
