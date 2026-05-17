import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_service.dart';
import '../../core/app_providers.dart';
import '../../design_system/colors/app_colors.dart';
import '../../design_system/typography/app_text_styles.dart';
import '../../design_system/spacing/app_spacing.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _membershipProvider =
    FutureProvider<Map<String, dynamic>>((ref) => ApiService.getMembershipStatus());

final _invoicesProvider = FutureProvider<List<dynamic>>((ref) => ApiService.getMyInvoices());

// ── Member Web View ───────────────────────────────────────────────────────────

class MemberWebView extends ConsumerWidget {
  const MemberWebView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('Member Portal', style: AppTextStyles.h4),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(appControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.textTertiary),
            label: Text(
              'Sign Out',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;
          return SingleChildScrollView(
            padding: EdgeInsets.all(isWide ? AppSpacing.xl : AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _MembershipCard(ref: ref)),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(flex: 6, child: _InvoiceList(ref: ref)),
                        ],
                      )
                    : Column(
                        children: [
                          _MembershipCard(ref: ref),
                          const SizedBox(height: AppSpacing.lg),
                          _InvoiceList(ref: ref),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Membership Status Card ────────────────────────────────────────────────────

class _MembershipCard extends ConsumerWidget {
  final WidgetRef ref;
  const _MembershipCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final async = r.watch(_membershipProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: async.when(
        loading: () => const _Skeleton(height: 160),
        error: (e, _) => _ErrorTile(message: e.toString()),
        data: (membership) {
          final status = membership['status'] as String? ?? 'unknown';
          final planName = membership['plan']?['name'] as String? ?? '—';
          final validUntil = membership['validUntil'] as String?;
          final isActive = status == 'active';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isActive ? Icons.verified_rounded : Icons.warning_rounded,
                    color: isActive ? AppColors.success : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Membership', style: AppTextStyles.h4),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _StatusBadge(status: status),
              const SizedBox(height: AppSpacing.md),
              _InfoRow(label: 'Plan', value: planName),
              if (validUntil != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _InfoRow(
                  label: 'Valid until',
                  value: _formatDate(validUntil),
                ),
              ],
              if (!isActive) ...[
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    child: const Text('Renew Membership'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Invoice List ──────────────────────────────────────────────────────────────

class _InvoiceList extends ConsumerWidget {
  final WidgetRef ref;
  const _InvoiceList({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final async = r.watch(_invoicesProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: AppColors.textSecondary, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text('Invoices', style: AppTextStyles.h4),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: _Skeleton(height: 120),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _ErrorTile(message: e.toString()),
            ),
            data: (invoices) {
              if (invoices.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      'No invoices yet.',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invoices.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, i) =>
                    _InvoiceRow(invoice: invoices[i] as Map<String, dynamic>),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const _InvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final number = invoice['number'] as String? ?? '—';
    final amount = invoice['amountDue'] as num? ?? 0;
    final currency = (invoice['currency'] as String? ?? 'eur').toUpperCase();
    final status = invoice['status'] as String? ?? '—';
    final pdfUrl = invoice['pdfUrl'] as String?;
    final createdAt = invoice['createdAt'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(number,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w500)),
                if (createdAt != null)
                  Text(
                    _formatDate(createdAt),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${(amount / 100).toStringAsFixed(2)} $currency',
              style: AppTextStyles.body,
            ),
          ),
          Expanded(
            flex: 2,
            child: _StatusChip(status: status),
          ),
          if (pdfUrl != null)
            IconButton(
              onPressed: () => _openPdf(pdfUrl),
              icon: const Icon(Icons.download_rounded,
                  size: 20, color: AppColors.primary),
              tooltip: 'Download PDF',
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            )
          else
            const SizedBox(width: 32),
        ],
      ),
    );
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'active' => (AppColors.success, 'Active'),
      'canceled' => (AppColors.error, 'Canceled'),
      'past_due' => (AppColors.warning, 'Past Due'),
      _ => (AppColors.textTertiary, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'paid' => AppColors.success,
      'open' => AppColors.warning,
      'void' || 'uncollectible' => AppColors.error,
      _ => AppColors.textTertiary,
    };

    return Text(
      status[0].toUpperCase() + status.substring(1),
      style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        Text(value,
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(message,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.error)),
        ),
      ],
    );
  }
}
