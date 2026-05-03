import 'package:flutter/material.dart';
import '../../design_system/colors/app_colors.dart';
import '../../design_system/typography/app_text_styles.dart';
import '../../design_system/spacing/app_spacing.dart';
import 'pages/dashboard_page.dart';
import 'pages/users_page.dart';
import 'pages/devices_page.dart';
import 'pages/logs_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.people_rounded, label: 'Users'),
    _NavItem(icon: Icons.sensors_rounded, label: 'Devices'),
    _NavItem(icon: Icons.list_alt_rounded, label: 'Logs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(
            selectedIndex: _selectedIndex,
            navItems: _navItems,
            onSelect: (i) => setState(() => _selectedIndex = i),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                DashboardPage(),
                UsersPage(),
                DevicesPage(),
                LogsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

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
          // Logo
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
          // Nav items
          ...navItems.asMap().entries.map((e) {
            final isSelected = e.key == selectedIndex;
            return _SidebarNavItem(
              item: e.value,
              isSelected: isSelected,
              onTap: () => onSelect(e.key),
            );
          }),
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
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: widget.isSelected
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: AppSpacing.iconLg,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.item.label,
                style: AppTextStyles.body.copyWith(
                  color:
                      isActive ? AppColors.primary : AppColors.textSecondary,
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
