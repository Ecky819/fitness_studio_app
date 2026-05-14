import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_service.dart';
import '../../core/app_providers.dart';
import '../../core/services/biometric_service.dart';
import '../../design_system/design_system.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _MemberProfile {
  final String email;
  final String membershipStatus;
  final String planName;
  final DateTime? validUntil;

  const _MemberProfile({
    required this.email,
    required this.membershipStatus,
    required this.planName,
    this.validUntil,
  });
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _memberProfileProvider =
    FutureProvider.autoDispose<_MemberProfile>((ref) async {
  final results = await Future.wait([
    ApiService.getProfile(),
    ApiService.getMembershipStatus(),
  ]);

  final profile = results[0];
  final membership = results[1];

  return _MemberProfile(
    email: profile['email'] as String? ?? '—',
    membershipStatus: membership['status'] as String? ?? 'unknown',
    planName: membership['planName'] as String? ??
        membership['plan'] as String? ??
        '—',
    validUntil:
        DateTime.tryParse(membership['validUntil'] as String? ?? ''),
  );
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (!value) {
      await BiometricService.disable();
      if (mounted) setState(() => _biometricEnabled = false);
    } else {
      // Biometrics can only be enabled from the login screen (requires password).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sign in with your password on the login screen to enable biometrics.',
              style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Sign Out', style: AppTextStyles.h4),
        content: Text(
          'You will need to sign in again to open the gym door.',
          style:
              AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(appControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_memberProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Profile', style: AppTextStyles.h4),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text('Could not load profile',
                    style: AppTextStyles.h4),
                const SizedBox(height: AppSpacing.sm),
                Text(e.toString(),
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textTertiary),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton(
                  onPressed: () => ref.refresh(_memberProfileProvider),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) => _ProfileBody(
          profile: profile,
          biometricAvailable: _biometricAvailable,
          biometricEnabled: _biometricEnabled,
          onBiometricToggle: _toggleBiometrics,
          onLogout: _logout,
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final _MemberProfile profile;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final ValueChanged<bool> onBiometricToggle;
  final VoidCallback onLogout;

  const _ProfileBody({
    required this.profile,
    required this.biometricAvailable,
    required this.biometricEnabled,
    required this.onBiometricToggle,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AvatarCard(email: profile.email),
          const SizedBox(height: AppSpacing.lg),
          _MembershipCard(profile: profile),
          if (biometricAvailable) ...[
            const SizedBox(height: AppSpacing.lg),
            _SecurityCard(
              biometricEnabled: biometricEnabled,
              onToggle: onBiometricToggle,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _SignOutButton(onLogout: onLogout),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ── Avatar Card ───────────────────────────────────────────────────────────────

class _AvatarCard extends StatelessWidget {
  final String email;
  const _AvatarCard({required this.email});

  @override
  Widget build(BuildContext context) {
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: AppTextStyles.h2.copyWith(color: Colors.black),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Member', style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                )),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Membership Card ───────────────────────────────────────────────────────────

class _MembershipCard extends StatelessWidget {
  final _MemberProfile profile;
  const _MembershipCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (profile.membershipStatus) {
      'active' || 'ACTIVE' => ('Active', AppColors.success),
      'past_due' || 'PAST_DUE' => ('Payment Due', AppColors.warning),
      'canceled' || 'CANCELED' => ('Cancelled', AppColors.error),
      _ => ('Inactive', AppColors.textTertiary),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const _SectionHeader(
            icon: Icons.card_membership_rounded,
            title: 'Membership',
          ),
          _InfoRow(
            label: 'Plan',
            value: profile.planName,
          ),
          _DividerLine(),
          _InfoRow(
            label: 'Status',
            valueWidget: _StatusChip(
              label: statusLabel,
              color: statusColor,
            ),
          ),
          _DividerLine(),
          _InfoRow(
            label: 'Valid until',
            value: profile.validUntil != null
                ? _formatDate(profile.validUntil!)
                : '—',
            valueColor: _validUntilColor(profile.validUntil),
          ),
        ],
      ),
    );
  }

  Color? _validUntilColor(DateTime? date) {
    if (date == null) return null;
    final daysLeft = date.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return AppColors.error;
    if (daysLeft <= 7) return AppColors.warning;
    return null;
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ── Security Card ─────────────────────────────────────────────────────────────

class _SecurityCard extends StatelessWidget {
  final bool biometricEnabled;
  final ValueChanged<bool> onToggle;

  const _SecurityCard({
    required this.biometricEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const _SectionHeader(
            icon: Icons.fingerprint_rounded,
            title: 'Security',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Biometric Login',
                          style: AppTextStyles.body),
                      const SizedBox(height: 2),
                      Text(
                        biometricEnabled
                            ? 'Face ID / Touch ID active'
                            : 'Enable on the login screen',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: biometricEnabled,
                  onChanged: onToggle,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                  inactiveTrackColor: AppColors.surfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sign-Out Button ───────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  final VoidCallback onLogout;
  const _SignOutButton({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onLogout,
      icon: const Icon(Icons.logout_rounded, size: 18),
      label: const Text('Sign Out'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? valueWidget;

  const _InfoRow({
    required this.label,
    this.value,
    this.valueColor,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary)),
          valueWidget ??
              Text(
                value ?? '—',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.border, indent: 16);
}

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
