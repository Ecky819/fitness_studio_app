import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_providers.dart';
import '../../core/api_service.dart';
import '../../design_system/design_system.dart';

class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
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

  Future<void> _startMembership() async {
    setState(() => _isLoading = true);

    try {
      // Create checkout session
      final checkoutData = await ApiService.createCheckoutSession();
      final checkoutUrl = checkoutData['url'] as String;

      // Open checkout URL
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch checkout URL';
      }

      // In a real app, you'd listen for webhook or redirect
      // For demo, simulate successful payment after a delay
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        ref.read(appControllerProvider.notifier).onPaymentSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to start membership: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                const Icon(
                  Icons.star,
                  size: 60,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Unlock Your\nFitness Journey',
                  style: AppTextStyles.h1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Get unlimited access to premium equipment and classes',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Membership plan card
                AppLightGlassContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        Text(
                          'Premium Membership',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '\$29',
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '/month',
                              style: AppTextStyles.body,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildFeature('24/7 gym access'),
                        _buildFeature('Premium equipment'),
                        _buildFeature('Group classes'),
                        _buildFeature('Personal training'),
                        _buildFeature('Mobile app access'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Start membership button
                AppPrimaryButton(
                  text: 'Start Membership',
                  isLoading: _isLoading,
                  onPressed: _startMembership,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Info text
                Text(
                  'Secure payment powered by Stripe',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: AppSpacing.iconMd,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            feature,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
