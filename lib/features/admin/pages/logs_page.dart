import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../models/admin_models.dart';
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
          loading: () => const PageHeader(
            title: 'Access Logs',
            subtitle: 'Loading…',
          ),
          error: (_, __) => const PageHeader(
            title: 'Access Logs',
            subtitle: '—',
          ),
          data: (logs) => PageHeader(
            title: 'Access Logs',
            subtitle: '${logs.length} entries',
          ),
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
                      onUserSearch: (v) => _applyFilter(LogFilter(
                        userSearch: v,
                        doorId: _filter.doorId,
                        dateFrom: _filter.dateFrom,
                        dateTo: _filter.dateTo,
                      )),
                      onDoorChanged: (v) => _applyFilter(LogFilter(
                        userSearch: _filter.userSearch,
                        doorId: v,
                        dateFrom: _filter.dateFrom,
                        dateTo: _filter.dateTo,
                      )),
                      onDateFromChanged: (v) => _applyFilter(LogFilter(
                        userSearch: _filter.userSearch,
                        doorId: _filter.doorId,
                        dateFrom: v,
                        dateTo: _filter.dateTo,
                      )),
                      onDateToChanged: (v) => _applyFilter(LogFilter(
                        userSearch: _filter.userSearch,
                        doorId: _filter.doorId,
                        dateFrom: _filter.dateFrom,
                        dateTo: v,
                      )),
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
                    style:
                        AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                  data: (logs) => _LogsTable(logs: logs),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final LogFilter filter;
  final TextEditingController userSearchController;
  final Map<String, String> doorOptions;
  final ValueChanged<String> onUserSearch;
  final ValueChanged<String?> onDoorChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;
  final VoidCallback onClear;

  const _FilterBar({
    required this.filter,
    required this.userSearchController,
    required this.doorOptions,
    required this.onUserSearch,
    required this.onDoorChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = filter.userSearch.isNotEmpty ||
        filter.doorId != null ||
        filter.dateFrom != null ||
        filter.dateTo != null;

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
          hint: Text(
            'All doors',
            style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
          ),
          style: AppTextStyles.body,
          dropdownColor: AppColors.surface,
          iconEnabledColor: AppColors.textTertiary,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'All doors',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ),
            ...options.entries.map((e) => DropdownMenuItem<String?>(
                  value: e.key,
                  child: Text(e.value),
                )),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _LogsTable extends StatelessWidget {
  final List<AccessLog> logs;
  const _LogsTable({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return AdminCard(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Center(
          child: Text(
            'No logs match the current filters.',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return AdminCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.surfaceVariant),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return AppColors.overlayHover;
            }
            return Colors.transparent;
          }),
          dividerThickness: 1,
          headingTextStyle: AppTextStyles.labelLarge
              .copyWith(color: AppColors.textSecondary),
          dataTextStyle: AppTextStyles.body,
          columns: const [
            DataColumn(label: Text('Timestamp')),
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Door')),
            DataColumn(label: Text('Result')),
            DataColumn(label: Text('Reason')),
          ],
          rows: logs.map((log) {
            return DataRow(cells: [
              DataCell(Text(
                formatTimestamp(log.timestamp),
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              )),
              DataCell(Text(log.userName)),
              DataCell(Text(log.deviceName)),
              DataCell(ResultBadge(granted: log.granted)),
              DataCell(Text(
                log.reason,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
