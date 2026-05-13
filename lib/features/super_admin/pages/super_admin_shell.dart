import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_service.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../../../features/admin/widgets/admin_widgets.dart';
import '../models/tenant_summary.dart';
import '../providers/super_admin_providers.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          _Sidebar(selected: _tab, onSelect: (i) => setState(() => _tab = i)),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                _PlatformStatsPage(),
                _TenantsPage(),
                _CreateTenantPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.selected, required this.onSelect});

  static const _items = [
    (icon: Icons.analytics_rounded, label: 'Platform Stats'),
    (icon: Icons.business_rounded, label: 'Gyms'),
    (icon: Icons.add_business_rounded, label: 'New Gym'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg,
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Platform', style: AppTextStyles.h4.copyWith(fontSize: 15)),
                  Text('Super Admin',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                ]),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          ..._items.asMap().entries.map((e) {
            final active = e.key == selected;
            return GestureDetector(
              onTap: () => onSelect(e.key),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: active
                      ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(children: [
                  Icon(e.value.icon, size: AppSpacing.iconLg,
                      color: active ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(e.value.label,
                      style: AppTextStyles.body.copyWith(
                        color: active ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      )),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Platform Stats ─────────────────────────────────────────────────────────────

class _PlatformStatsPage extends ConsumerWidget {
  const _PlatformStatsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(platformStatsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeader(
        title: 'Platform Stats',
        subtitle: 'All gyms on the NextGen Gym OS platform',
        action: IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: () => ref.invalidate(platformStatsProvider),
        ),
      ),
      Expanded(child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AdminCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(children: [
                const Icon(Icons.business_rounded, color: AppColors.primary, size: 32),
                const SizedBox(width: AppSpacing.md),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${stats.totalTenants}',
                      style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
                  Text('Total Gyms',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                ]),
              ]),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('By Plan', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.md),
            if (stats.byPlan.isNotEmpty)
              Row(children: stats.byPlan.map((p) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: StatCard(
                    label: p.plan, value: '${p.count}',
                    icon: Icons.star_rounded, color: _planColor(p.plan),
                  ),
                ),
              )).toList()),
            const SizedBox(height: AppSpacing.xl),
            Text('By Status', style: AppTextStyles.h4),
            const SizedBox(height: AppSpacing.md),
            if (stats.byStatus.isNotEmpty)
              Row(children: stats.byStatus.map((s) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: StatCard(
                    label: s.status, value: '${s.count}',
                    icon: Icons.circle, color: _statusColor(s.status),
                  ),
                ),
              )).toList()),
          ]),
        ),
      )),
    ]);
  }

  Color _planColor(String p) => switch (p) {
    'ENTERPRISE' => AppColors.primary,
    'PRO' => AppColors.info,
    _ => AppColors.textTertiary,
  };

  Color _statusColor(String s) => switch (s) {
    'ACTIVE' => AppColors.success,
    'TRIAL' => AppColors.warning,
    _ => AppColors.error,
  };
}

// ── Tenants Table ─────────────────────────────────────────────────────────────

class _TenantsPage extends ConsumerStatefulWidget {
  const _TenantsPage();
  @override
  ConsumerState<_TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends ConsumerState<_TenantsPage> {
  final _search = TextEditingController();
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(tenantsNotifierProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeader(
        title: 'Gyms',
        subtitle: 'Manage all tenant gyms on the platform',
        action: IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: () => ref.read(tenantsNotifierProvider.notifier).refresh(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
        child: TextField(
          controller: _search,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: 'Search gyms…',
            hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            filled: true, fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          ),
          onSubmitted: (q) => ref.read(tenantsNotifierProvider.notifier).search(q),
        ),
      ),
      Expanded(child: tenantsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tenants) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
          child: AdminCard(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
              headingTextStyle: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
              dataTextStyle: AppTextStyles.body,
              columns: const [
                DataColumn(label: Text('Gym')),
                DataColumn(label: Text('Slug')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Users')),
                DataColumn(label: Text('Actions')),
              ],
              rows: tenants.map((t) => DataRow(cells: [
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.gymName ?? t.name),
                    Text(t.name, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                  ],
                )),
                DataCell(Text(t.slug, style: AppTextStyles.body.copyWith(color: AppColors.textTertiary))),
                DataCell(_PlanBadge(plan: t.plan)),
                DataCell(_StatusBadge(status: t.status)),
                DataCell(Text('${t.userCount}')),
                DataCell(Row(children: [
                  PopupMenuButton<String>(
                    tooltip: 'Change plan',
                    icon: const Icon(Icons.upgrade_rounded, size: 18, color: AppColors.textSecondary),
                    itemBuilder: (_) => ['STARTER', 'PRO', 'ENTERPRISE']
                        .map((p) => PopupMenuItem(value: p, child: Text(p))).toList(),
                    onSelected: (p) => ref.read(tenantsNotifierProvider.notifier).updatePlan(t.id, p),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Change status',
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textSecondary),
                    itemBuilder: (_) => ['ACTIVE', 'TRIAL', 'SUSPENDED', 'CANCELLED']
                        .map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                    onSelected: (s) => ref.read(tenantsNotifierProvider.notifier).updateStatus(t.id, s),
                  ),
                ])),
              ])).toList(),
            ),
          )),
        ),
      )),
    ]);
  }
}

// ── Create Tenant ──────────────────────────────────────────────────────────────

class _CreateTenantPage extends StatefulWidget {
  const _CreateTenantPage();
  @override
  State<_CreateTenantPage> createState() => _CreateTenantPageState();
}

class _CreateTenantPageState extends State<_CreateTenantPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _gymName = TextEditingController();
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _name.dispose(); _slug.dispose(); _gymName.dispose(); _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.createTenant({
        'name': _name.text.trim(),
        'slug': _slug.text.trim().toLowerCase(),
        'gymName': _gymName.text.trim(),
        if (_email.text.isNotEmpty) 'supportEmail': _email.text.trim(),
      });
      if (mounted) setState(() { _success = true; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageHeader(title: 'New Gym', subtitle: 'Onboard a new gym onto the platform'),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: _success
            ? AdminCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  Text('Gym created!', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(onPressed: () => setState(() => _success = false),
                      child: const Text('Create another')),
                ]),
              )
            : AdminCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _form,
                  child: SizedBox(
                    width: 480,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _Field(controller: _name, label: 'Company Name', hint: 'Iron Palace GmbH',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                      const SizedBox(height: AppSpacing.md),
                      _Field(
                        controller: _slug, label: 'Subdomain Slug', hint: 'iron-palace',
                        helper: 'Accessible at: <slug>.gymOS.io',
                        validator: (v) {
                          if (v!.trim().isEmpty) return 'Required';
                          if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v)) return 'Lowercase, numbers, hyphens only';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _Field(controller: _gymName, label: 'Display Name', hint: 'Iron Palace',
                          validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                      const SizedBox(height: AppSpacing.md),
                      _Field(controller: _email, label: 'Support Email (optional)', hint: 'support@ironpalace.de'),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(_error!, style: AppTextStyles.body.copyWith(color: AppColors.error)),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Text('Create Gym'),
                      ),
                    ]),
                  ),
                ),
              ),
      )),
    ]);
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final String? helper;
  final String? Function(String?)? validator;

  const _Field({required this.controller, required this.label, required this.hint,
      this.helper, this.validator});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTextStyles.body.copyWith(
          color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        style: AppTextStyles.body,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
          helperText: helper,
          helperStyle: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          filled: true, fillColor: AppColors.surfaceVariant,
          contentPadding: const EdgeInsets.all(AppSpacing.md),
        ),
      ),
    ],
  );
}

class _PlanBadge extends StatelessWidget {
  final String plan;
  const _PlanBadge({required this.plan});

  @override
  Widget build(BuildContext context) {
    final c = switch (plan) {
      'ENTERPRISE' => AppColors.primary,
      'PRO' => AppColors.info,
      _ => AppColors.textTertiary,
    };
    return _Chip(label: plan, color: c);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = switch (status) {
      'ACTIVE' => AppColors.success,
      'TRIAL' => AppColors.warning,
      _ => AppColors.error,
    };
    return _Chip(label: status, color: c);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label,
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
  );
}
