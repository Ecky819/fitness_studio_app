import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final _userSearchController = TextEditingController();
  LogFilter _filter = const LogFilter();

  @override
  void dispose() {
    _userSearchController.dispose();
    super.dispose();
  }

  void _applyFilter(LogFilter filter) {
    setState(() => _filter = filter);
    ref.read(logsNotifierProvider.notifier).applyFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(logsNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        logsAsync.when(
          loading: () =>
              const PageHeader(title: 'Access Logs', subtitle: 'Loading…'),
          error: (_, __) =>
              const PageHeader(title: 'Access Logs', subtitle: '—'),
          data: (logs) =>
              PageHeader(title: 'Access Logs', subtitle: '${logs.length} entries'),
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
                logsAsync.maybeWhen(
                  data: (logs) {
                    final doorOptions = {
                      for (final log in logs) log.deviceId: log.deviceName,
                    };
                    return _FilterBar(
                      filter: _filter,
                      userSearchController: _userSearchController,
                      doorOptions: doorOptions,
                      onUserSearch: (v) =>
                          _applyFilter(_filter.copyWith(userSearch: v)),
                      onDoorChanged: (v) =>
                          _applyFilter(_filter.copyWith(doorId: v)),
                      onDateFromChanged: (v) =>
                          _applyFilter(_filter.copyWith(dateFrom: v)),
                      onDateToChanged: (v) =>
                          _applyFilter(_filter.copyWith(dateTo: v)),
                      onStatusChanged: (v) =>
                          _applyFilter(_filter.copyWith(status: v)),
                    onClear: () {
                        _userSearchController.clear();
                        _applyFilter(const LogFilter());
                      },
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.md),
                logsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text(
                    'Error: $e',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  data: (logs) => logs.isEmpty
                      ? AdminCard(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Center(
                            child: Text(
                              'No logs match the current filters.',
                              style: AppTextStyles.body
                                  .copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : AdminCard(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: AccessLogDataTable(logs: logs),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Filter Bar ─────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final LogFilter filter;
  final TextEditingController userSearchController;
  final Map<String, String> doorOptions;
  final ValueChanged<String> onUserSearch;
  final ValueChanged<String?> onDoorChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onClear;

  const _FilterBar({
    required this.filter,
    required this.userSearchController,
    required this.doorOptions,
    required this.onUserSearch,
    required this.onDoorChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.onStatusChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = filter.userSearch.isNotEmpty ||
        filter.doorId != null ||
        filter.dateFrom != null ||
        filter.dateTo != null ||
        filter.status != null;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: userSearchController,
            onChanged: onUserSearch,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Search user…',
              hintStyle:
                  AppTextStyles.body.copyWith(color: AppColors.textTertiary),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textTertiary),
              isDense: true,
            ),
          ),
        ),
        _DoorDropdown(
          selectedId: filter.doorId,
          options: doorOptions,
          onChanged: onDoorChanged,
        ),
        _DatePickerButton(
          label: filter.dateFrom != null
              ? 'From: ${formatDate(filter.dateFrom!)}'
              : 'From date',
          onPick: (ctx) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: filter.dateFrom ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
              builder: (ctx, child) => _darkDatePicker(ctx, child),
            );
            onDateFromChanged(picked);
          },
        ),
        _DatePickerButton(
          label: filter.dateTo != null
              ? 'To: ${formatDate(filter.dateTo!)}'
              : 'To date',
          onPick: (ctx) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: filter.dateTo ?? DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
              builder: (ctx, child) => _darkDatePicker(ctx, child),
            );
            onDateToChanged(picked);
          },
        ),
        _StatusFilter(
          selected: filter.status,
          onChanged: onStatusChanged,
        ),
        if (hasActiveFilter)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all_rounded, size: 18),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _darkDatePicker(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
      ),
      child: child!,
    );
  }
}

class _DoorDropdown extends StatelessWidget {
  final String? selectedId;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  const _DoorDropdown({
    required this.selectedId,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedId,
          hint: Text('All doors',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textTertiary)),
          style: AppTextStyles.body,
          dropdownColor: AppColors.surface,
          iconEnabledColor: AppColors.textTertiary,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('All doors',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
            ),
            ...options.entries.map((e) =>
                DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final void Function(BuildContext) onPick;

  const _DatePickerButton({required this.label, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onPick(context),
      icon: const Icon(Icons.calendar_today_rounded, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  static const _options = [
    (label: 'All', value: null, icon: Icons.list_rounded),
    (label: 'Granted', value: 'GRANTED', icon: Icons.check_circle_outline_rounded),
    (label: 'Denied', value: 'DENIED', icon: Icons.cancel_outlined),
  ];

  const _StatusFilter({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _options.map((opt) {
        final isSelected = selected == opt.value;
        final color = opt.value == 'GRANTED'
            ? AppColors.success
            : opt.value == 'DENIED'
                ? AppColors.error
                : AppColors.textSecondary;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(opt.icon, size: 14,
                    color: isSelected ? color : AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(opt.label),
              ],
            ),
            selected: isSelected,
            onSelected: (_) =>
                onChanged(isSelected ? null : opt.value),
            selectedColor: color.withValues(alpha: 0.15),
            checkmarkColor: color,
            labelStyle: AppTextStyles.body.copyWith(
              color: isSelected ? color : AppColors.textSecondary,
              fontSize: 13,
            ),
            backgroundColor: AppColors.surfaceVariant,
            side: BorderSide(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          ),
        );
      }).toList(),
    );
  }
}
