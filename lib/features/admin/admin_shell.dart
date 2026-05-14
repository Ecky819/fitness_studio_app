import 'package:flutter/material.dart';
import '../../design_system/colors/app_colors.dart';
import '../../design_system/typography/app_text_styles.dart';
import '../../design_system/spacing/app_spacing.dart';
import 'pages/analytics_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/devices_page.dart';
import 'pages/insights_page.dart';
import 'pages/logs_page.dart';
import 'pages/users_page.dart';

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
  ];

  static const _pages = [
    DashboardPage(),
    AnalyticsPage(),
    InsightsPage(),
    UsersPage(),
    DevicesPage(),
    LogsPage(),
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
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'v1.0.0',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
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
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'v1.0.0',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
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
