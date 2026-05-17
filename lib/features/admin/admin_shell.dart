import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_providers.dart';
import '../../design_system/colors/app_colors.dart';
import '../../design_system/typography/app_text_styles.dart';
import '../../design_system/spacing/app_spacing.dart';
import 'pages/analytics_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/devices_page.dart';
import 'pages/insights_page.dart';
import 'pages/logs_page.dart';
import 'pages/pricing_page.dart';
import 'pages/users_page.dart';
import 'providers/admin_providers.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.bar_chart_rounded, label: 'Analytics'),
    _NavItem(icon: Icons.psychology_rounded, label: 'AI Insights'),
    _NavItem(icon: Icons.people_rounded, label: 'Users'),
    _NavItem(icon: Icons.sensors_rounded, label: 'Devices'),
    _NavItem(icon: Icons.list_alt_rounded, label: 'Logs'),
    _NavItem(icon: Icons.local_offer_rounded, label: 'Pricing'),
  ];

  static const _pages = [
    DashboardPage(),
    AnalyticsPage(),
    InsightsPage(),
    UsersPage(),
    DevicesPage(),
    LogsPage(),
    PricingPage(),
  ];

  void _select(int i) => setState(() => _selectedIndex = i);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _MobileShell(
            selectedIndex: _selectedIndex,
            navItems: _navItems,
            pages: _pages,
            onSelect: _select,
          );
        }
        if (constraints.maxWidth < 1024) {
          return _TabletShell(
            selectedIndex: _selectedIndex,
            navItems: _navItems,
            pages: _pages,
            onSelect: _select,
          );
        }
        return _DesktopShell(
          selectedIndex: _selectedIndex,
          navItems: _navItems,
          pages: _pages,
          onSelect: _select,
        );
      },
    );
  }
}

// ── Desktop Shell ─────────────────────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final List<Widget> pages;
  final ValueChanged<int> onSelect;

  const _DesktopShell({
    required this.selectedIndex,
    required this.navItems,
    required this.pages,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: selectedIndex,
            navItems: navItems,
            onSelect: onSelect,
          ),
          const VerticalDivider(
              width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: IndexedStack(index: selectedIndex, children: pages),
          ),
        ],
      ),
    );
  }
}

// ── Tablet Shell (600–1023 px) ────────────────────────────────────────────────

class _TabletShell extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final List<Widget> pages;
  final ValueChanged<int> onSelect;

  const _TabletShell({
    required this.selectedIndex,
    required this.navItems,
    required this.pages,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Collapsed icon-only rail on tablet
          NavigationRail(
            backgroundColor: AppColors.surface,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            labelType: NavigationRailLabelType.selected,
            selectedIconTheme: const IconThemeData(color: AppColors.primary),
            unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
            selectedLabelTextStyle: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            destinations: navItems
                .map((item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(item.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: IndexedStack(index: selectedIndex, children: pages),
          ),
        ],
      ),
    );
  }
}

// ── Mobile Shell ──────────────────────────────────────────────────────────────

class _MobileShell extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final List<Widget> pages;
  final ValueChanged<int> onSelect;

  const _MobileShell({
    required this.selectedIndex,
    required this.navItems,
    required this.pages,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final currentLabel = navItems[selectedIndex].label;

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
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(currentLabel, style: AppTextStyles.h4),
          ],
        ),
        iconTheme:
            const IconThemeData(color: AppColors.textPrimary),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      drawer: _MobileDrawer(
        selectedIndex: selectedIndex,
        navItems: navItems,
        onSelect: (i) {
          Navigator.pop(context);
          onSelect(i);
        },
      ),
      body: IndexedStack(index: selectedIndex, children: pages),
    );
  }
}

// ── Mobile Drawer ─────────────────────────────────────────────────────────────

class _MobileDrawer extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final ValueChanged<int> onSelect;

  const _MobileDrawer({
    required this.selectedIndex,
    required this.navItems,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FitAdmin',
                          style:
                              AppTextStyles.h4.copyWith(fontSize: 16)),
                      Text(
                        'Control Panel',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: AppSpacing.sm),
            ...navItems.asMap().entries.map((e) => _DrawerNavItem(
                  item: e.value,
                  isSelected: e.key == selectedIndex,
                  onTap: () => onSelect(e.key),
                )),
            const Spacer(),
            const Divider(color: AppColors.border, height: 1),
            const _ProfileFooter(),
          ],
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                    color:
                        AppColors.primary.withValues(alpha: 0.3)),
              )
            : null,
        child: Row(
          children: [
            Icon(
              item.icon,
              size: AppSpacing.iconLg,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              item.label,
              style: AppTextStyles.body.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontWeight: isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Desktop Sidebar ───────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.selectedIndex,
    required this.navItems,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FitAdmin',
                      style: AppTextStyles.h4.copyWith(fontSize: 16),
                    ),
                    Text(
                      'Control Panel',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          ...navItems.asMap().entries.map((e) => _SidebarNavItem(
                item: e.value,
                isSelected: e.key == selectedIndex,
                onTap: () => onSelect(e.key),
              )),
          const Spacer(),
          const Divider(color: AppColors.border, height: 1),
          const _ProfileFooter(),
        ],
      ),
    );
  }
}

// ── Shared types ──────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _SidebarNavItem extends StatefulWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isSelected || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : _isHovered
                    ? AppColors.overlayHover
                    : Colors.transparent,
            borderRadius:
                BorderRadius.circular(AppSpacing.radiusMd),
            border: widget.isSelected
                ? Border.all(
                    color:
                        AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: AppSpacing.iconLg,
                color: isActive
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.item.label,
                style: AppTextStyles.body.copyWith(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile Footer ─────────────────────────────────────────────────────────────

class _ProfileFooter extends ConsumerWidget {
  const _ProfileFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(adminProfileProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: profileAsync.when(
        loading: () => const _ProfileSkeleton(),
        error: (_, __) => _buildRow(
          initials: '?',
          email: 'Admin',
          role: '',
          ref: ref,
          context: context,
        ),
        data: (profile) {
          final email = profile['email'] as String? ?? '';
          final role = profile['role'] as String? ?? 'ADMIN';
          final initials = _initials(email);
          return _buildRow(
            initials: initials,
            email: email,
            role: role,
            ref: ref,
            context: context,
          );
        },
      ),
    );
  }

  Widget _buildRow({
    required String initials,
    required String email,
    required String role,
    required WidgetRef ref,
    required BuildContext context,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initials,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                email,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (role.isNotEmpty)
                Text(
                  role,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _confirmLogout(context, ref),
          icon: const Icon(Icons.logout_rounded, size: 18),
          color: AppColors.textTertiary,
          tooltip: 'Sign out',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  String _initials(String email) {
    final local = email.split('@').first;
    final parts = local.split(RegExp(r'[._\-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Sign Out?', style: AppTextStyles.h4),
        content: Text(
          'You will be returned to the login screen.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sign Out',
              style: AppTextStyles.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(appControllerProvider.notifier).logout();
    }
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 11,
                width: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 9,
                width: 50,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
