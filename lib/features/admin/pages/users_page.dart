import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPageScaffold(
      value: ref.watch(usersNotifierProvider),
      title: 'Users',
      builder: (users) {
        final filtered = _searchQuery.isEmpty
            ? users
            : users.where((u) {
                final q = _searchQuery.toLowerCase();
                return u.name.toLowerCase().contains(q) ||
                    u.email.toLowerCase().contains(q);
              }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Users',
              subtitle: '${users.length} registered members',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchBar(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _UsersTable(
                      users: filtered,
                      hasActiveSearch: _searchQuery.isNotEmpty,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Search by name or email…',
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textTertiary),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

class _UsersTable extends ConsumerWidget {
  final List<AdminUser> users;
  final bool hasActiveSearch;
  const _UsersTable({required this.users, this.hasActiveSearch = false});

  Future<void> _confirmToggleBlock(
    BuildContext context,
    WidgetRef ref,
    AdminUser user,
  ) async {
    final action = user.isBlocked ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('$action User?', style: AppTextStyles.h4),
        content: Text(
          'Are you sure you want to ${action.toLowerCase()} ${user.email}?',
          style: AppTextStyles.body
              .copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: AppTextStyles.body.copyWith(
                color: user.isBlocked
                    ? AppColors.success
                    : AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.read(usersNotifierProvider.notifier).toggleBlock(user.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (users.isEmpty) {
      return AdminCard(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxl,
          horizontal: AppSpacing.lg,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasActiveSearch
                    ? Icons.search_off_rounded
                    : Icons.people_outline_rounded,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                hasActiveSearch
                    ? 'No users match your search'
                    : 'No members yet',
                style: AppTextStyles.h4
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                hasActiveSearch
                    ? 'Try a different name or email address.'
                    : 'Registered members will appear here.',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return AdminCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
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
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Plan')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Valid Until')),
            DataColumn(label: Text('Actions')),
          ],
          rows: users.map((user) {
            return DataRow(cells: [
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Avatar(name: user.name),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(user.name,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w500)),
                      if (user.isBlocked)
                        Text('BLOCKED',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.error)),
                    ],
                  ),
                ],
              )),
              DataCell(Text(user.email,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(user.plan,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary)),
              )),
              DataCell(MembershipBadge(status: user.membershipStatus.name)),
              DataCell(Text(
                formatDate(user.validUntil),
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              )),
              DataCell(_BlockButton(
                isBlocked: user.isBlocked,
                onTap: () =>
                    _confirmToggleBlock(context, ref, user),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Container(
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
    );
  }
}

class _BlockButton extends StatelessWidget {
  final bool isBlocked;
  final VoidCallback onTap;

  const _BlockButton({required this.isBlocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(
        isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
        size: 16,
      ),
      label: Text(isBlocked ? 'Unblock' : 'Block'),
      style: TextButton.styleFrom(
        foregroundColor: isBlocked ? AppColors.success : AppColors.error,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );
  }
}
