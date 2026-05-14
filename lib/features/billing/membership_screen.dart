import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_providers.dart';
import '../../core/api_service.dart';
import '../../design_system/design_system.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class MembershipPlan {
  final String id;
  final String name;
  final int amountCents;
  final String interval;

  const MembershipPlan({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.interval,
  });

  factory MembershipPlan.fromJson(Map<String, dynamic> json) => MembershipPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        amountCents: json['amountCents'] as int? ?? 0,
        interval: json['interval'] as String? ?? 'month',
      );

  String get priceFormatted {
    final euros = (amountCents / 100);
    return euros == euros.truncateToDouble()
        ? '€${euros.toInt()}'
        : '€${euros.toStringAsFixed(2)}';
  }

  String get intervalLabel => switch (interval) {
        'month' => 'month',
        'year' => 'year',
        _ => interval,
      };
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _plansProvider =
    FutureProvider.autoDispose<List<MembershipPlan>>((ref) async {
  final raw = await ApiService.getPlans();
  return raw
      .map((e) => MembershipPlan.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MembershipScreen extends ConsumerStatefulWidget {
  final String planId;
  const MembershipScreen({super.key, this.planId = ''});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen>
    with TickerProviderStateMixin {
  MembershipPlan? _selectedPlan;
  bool _isLoading = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    final plan = _selectedPlan;
    if (plan == null) return;

    setState(() => _isLoading = true);

    try {
      final checkoutData =
          await ApiService.createCheckoutSession(plan.id);
      final checkoutUrl = checkoutData['url'] as String?;

      if (checkoutUrl == null) throw 'No checkout URL returned.';

      final uri = Uri.parse(checkoutUrl);
      if (!await canLaunchUrl(uri)) throw 'Could not open payment page.';

      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // Real apps await a webhook redirect; simulate here for the demo.
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        ref.read(appControllerProvider.notifier).onPaymentSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(_plansProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: plansAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              message: e.toString(),
              onRetry: () => ref.refresh(_plansProvider),
            ),
            data: (plans) {
              // Auto-select first plan if not already set.
              if (_selectedPlan == null && plans.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedPlan = plans.first);
                });
              }

              return plans.isEmpty
                  ? _NoPlanView(
                      onRefresh: () => ref.refresh(_plansProvider))
                  : _PlanSelector(
                      plans: plans,
                      selected: _selectedPlan,
                      isLoading: _isLoading,
                      onSelect: (p) =>
                          setState(() => _selectedPlan = p),
                      onCheckout: _startCheckout,
                    );
            },
          ),
        ),
      ),
    );
  }
}

// ── Plan Selector ─────────────────────────────────────────────────────────────

class _PlanSelector extends StatelessWidget {
  final List<MembershipPlan> plans;
  final MembershipPlan? selected;
  final bool isLoading;
  final ValueChanged<MembershipPlan> onSelect;
  final VoidCallback onCheckout;

  const _PlanSelector({
    required this.plans,
    required this.selected,
    required this.isLoading,
    required this.onSelect,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Choose Your Plan',
            style: AppTextStyles.h1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Get 24/7 access and unlock all gym features',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Plan cards
          ...plans.map((plan) => _PlanCard(
                plan: plan,
                isSelected: selected?.id == plan.id,
                onTap: () => onSelect(plan),
              )),
          const SizedBox(height: AppSpacing.xl),

          // CTA
          AppPrimaryButton(
            text: selected != null
                ? 'Start ${selected!.name}'
                : 'Select a plan',
            isLoading: isLoading,
            onPressed: selected != null ? onCheckout : null,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                'Secure payment via Stripe',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final MembershipPlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                  width: 2,
                ),
                color: isSelected
                    ? AppColors.primary
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),

            // Plan name + interval
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'per ${plan.intervalLabel}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),

            // Price
            Text(
              plan.priceFormatted,
              style: AppTextStyles.h3.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── State views ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load plans', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(text: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _NoPlanView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _NoPlanView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text('No plans available', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your gym has not configured any membership plans yet.\nPlease contact your gym administrator.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
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
