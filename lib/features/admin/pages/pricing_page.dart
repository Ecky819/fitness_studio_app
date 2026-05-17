import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_service.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../widgets/admin_widgets.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

class PricingRule {
  final String id;
  final String name;
  final List<int> daysOfWeek;
  final String timeFrom;
  final String timeTo;
  final double modifier;
  bool isActive;

  PricingRule({
    required this.id,
    required this.name,
    required this.daysOfWeek,
    required this.timeFrom,
    required this.timeTo,
    required this.modifier,
    required this.isActive,
  });

  factory PricingRule.fromJson(Map<String, dynamic> j) => PricingRule(
        id: j['id'] as String,
        name: j['name'] as String,
        daysOfWeek: ((j['daysOfWeek'] as List?) ?? []).map((e) => e as int).toList(),
        timeFrom: j['timeFrom'] as String? ?? '00:00',
        timeTo: j['timeTo'] as String? ?? '00:00',
        modifier: (j['modifier'] as num?)?.toDouble() ?? 0,
        isActive: j['isActive'] as bool? ?? true,
      );

  String get modifierLabel {
    final pct = (modifier * 100).round();
    return pct > 0 ? '+$pct% (Peak)' : '$pct% (Off-Peak)';
  }

  Color get modifierColor => modifier > 0 ? AppColors.error : AppColors.success;

  String get daysLabel {
    const names = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return daysOfWeek.map((d) => names[(d - 1).clamp(0, 6)]).join(', ');
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

class PricingNotifier extends AsyncNotifier<List<PricingRule>> {
  @override
  Future<List<PricingRule>> build() => _fetch();

  Future<List<PricingRule>> _fetch() async {
    final raw = await ApiService.getPricingRules();
    return raw.map((e) => PricingRule.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> toggle(String id) async {
    await ApiService.togglePricingRule(id);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> delete(String id) async {
    await ApiService.deletePricingRule(id);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> create(Map<String, dynamic> body) async {
    await ApiService.createPricingRule(body);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final pricingNotifierProvider =
    AsyncNotifierProvider<PricingNotifier, List<PricingRule>>(PricingNotifier.new);

// ── Page ───────────────────────────────────────────────────────────────────────

class PricingPage extends ConsumerWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(pricingNotifierProvider);

    return AsyncPageScaffold(
      value: rulesAsync,
      title: 'Dynamic Pricing',
      builder: (rules) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Dynamic Pricing',
            subtitle: '${rules.length} rule${rules.length == 1 ? '' : 's'} configured',
            action: IconButton(
              icon: const Icon(Icons.add_rounded, size: 22),
              onPressed: () => _showAddSheet(context, ref),
              tooltip: 'Add rule',
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rules.isEmpty)
                    _EmptyState(onAdd: () => _showAddSheet(context, ref))
                  else
                    _RulesList(rules: rules),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (_) => _AddRuleSheet(
        onSave: (body) => ref.read(pricingNotifierProvider.notifier).create(body),
      ),
    );
  }
}

// ── Rules List ─────────────────────────────────────────────────────────────────

class _RulesList extends ConsumerWidget {
  final List<PricingRule> rules;
  const _RulesList({required this.rules});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminCard(
      child: Column(
        children: rules.asMap().entries.map((entry) {
          final i = entry.key;
          final rule = entry.value;
          return Column(
            children: [
              _RuleItem(
                rule: rule,
                onToggle: () => ref.read(pricingNotifierProvider.notifier).toggle(rule.id),
                onDelete: () => _confirmDelete(context, ref, rule),
              ),
              if (i < rules.length - 1)
                const Divider(height: 1, color: AppColors.border, indent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, PricingRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Delete Rule?', style: AppTextStyles.h4),
        content: Text(
          'Delete "${rule.name}"? This cannot be undone.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.body.copyWith(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: AppTextStyles.body.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(pricingNotifierProvider.notifier).delete(rule.id);
    }
  }
}

class _RuleItem extends StatelessWidget {
  final PricingRule rule;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RuleItem({required this.rule, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: rule.modifierColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(color: rule.modifierColor.withValues(alpha: 0.3)),
            ),
            child: Text(rule.modifierLabel,
                style: AppTextStyles.caption.copyWith(color: rule.modifierColor, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
                Text(
                  '${rule.daysLabel}  ·  ${rule.timeFrom}–${rule.timeTo}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Switch(
            value: rule.isActive,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
            inactiveTrackColor: AppColors.surfaceVariant,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.textTertiary,
            onPressed: onDelete,
            tooltip: 'Delete',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_offer_rounded, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text('No pricing rules yet', style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add off-peak discounts or peak surcharges\nto optimise gym utilisation.',
              style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add First Rule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add Rule Sheet ─────────────────────────────────────────────────────────────

class _AddRuleSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> body) onSave;
  const _AddRuleSheet({required this.onSave});

  @override
  State<_AddRuleSheet> createState() => _AddRuleSheetState();
}

class _AddRuleSheetState extends State<_AddRuleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _timeFromCtrl = TextEditingController(text: '06:00');
  final _timeToCtrl = TextEditingController(text: '10:00');

  // ISO day numbers 1=Mon … 7=Sun
  final Set<int> _selectedDays = {1, 2, 3, 4, 5};
  double _modifier = -0.2; // -20% off-peak default
  bool _saving = false;

  static const _dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _timeFromCtrl.dispose();
    _timeToCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one day')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave({
        'name': _nameCtrl.text.trim(),
        'daysOfWeek': _selectedDays.toList()..sort(),
        'timeFrom': _timeFromCtrl.text.trim(),
        'timeTo': _timeToCtrl.text.trim(),
        'modifier': _modifier,
        'isActive': true,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_modifier * 100).round();
    final modColor = _modifier > 0 ? AppColors.error : AppColors.success;
    final modLabel = pct > 0 ? '+$pct% Peak surcharge' : '$pct% Off-peak discount';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xl, AppSpacing.xl,
          AppSpacing.xl + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('New Pricing Rule', style: AppTextStyles.h4),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: AppColors.textTertiary,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Name
            TextFormField(
              controller: _nameCtrl,
              style: AppTextStyles.body,
              decoration: const InputDecoration(labelText: 'Rule name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Modifier slider
            Text('Price modifier', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Slider(
                  value: _modifier,
                  min: -0.5,
                  max: 0.5,
                  divisions: 20,
                  activeColor: modColor,
                  onChanged: (v) => setState(() => _modifier = v),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: modColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(modLabel, style: AppTextStyles.caption.copyWith(color: modColor, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),

            // Days of week
            Text('Days', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(_dayNames[i], style: AppTextStyles.caption),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) { _selectedDays.add(day); } else { _selectedDays.remove(day); }
                  }),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primary,
                  side: BorderSide(
                    color: selected ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border,
                  ),
                  backgroundColor: AppColors.surfaceVariant,
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Time range
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _timeFromCtrl,
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(labelText: 'From (HH:MM)'),
                  validator: _validateTime,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _timeToCtrl,
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(labelText: 'To (HH:MM)'),
                  validator: _validateTime,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.xl),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Rule', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateTime(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final parts = v.trim().split(':');
    if (parts.length != 2) return 'Use HH:MM';
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h > 23 || m > 59) return 'Invalid time';
    return null;
  }
}
