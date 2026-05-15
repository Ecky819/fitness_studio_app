import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../design_system/colors/app_colors.dart';
import '../../../design_system/typography/app_text_styles.dart';
import '../../../design_system/spacing/app_spacing.dart';
import '../models/admin_models.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_widgets.dart';

class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncPageScaffold(
      value: ref.watch(devicesProvider),
      title: 'Devices',
      builder: (devices) {
        final onlineCount = devices.where((d) => d.isOnline).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Devices',
              subtitle: '$onlineCount of ${devices.length} devices online',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: _DevicesGrid(devices: devices),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DevicesGrid extends StatelessWidget {
  final List<Device> devices;
  const _DevicesGrid({required this.devices});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xxl,
          horizontal: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sensors_off_rounded,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.md),
              Text('No devices configured',
                  style: AppTextStyles.h4
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Add your first door controller in the backend\nto start managing gym access.',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : 2;
        final itemWidth =
            (constraints.maxWidth - (crossAxisCount - 1) * AppSpacing.md) /
                crossAxisCount;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: devices.map((d) {
            return SizedBox(width: itemWidth, child: _DeviceCard(device: d));
          }).toList(),
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  const _DeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final borderColor = device.isOnline
        ? AppColors.success.withValues(alpha: 0.3)
        : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  Icons.sensors_rounded,
                  color: device.isOnline
                      ? AppColors.success
                      : AppColors.textTertiary,
                  size: 22,
                ),
              ),
              const Spacer(),
              OnlineBadge(isOnline: device.isOnline),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(device.name, style: AppTextStyles.h4.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text(device.location,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          _MetaRow(
            icon: Icons.touch_app_rounded,
            label: 'Today',
            value: '${device.accessCount} accesses',
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetaRow(
            icon: Icons.access_time_rounded,
            label: 'Last active',
            value: timeAgo(device.lastActivity),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetaRow(
            icon: Icons.memory_rounded,
            label: 'Firmware',
            value: device.firmwareVersion,
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetaRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text('$label:',
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
