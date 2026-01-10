import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../domain/models/vault_entry.dart';

/// A widget for selecting a retention period.
class RetentionSelector extends StatelessWidget {
  const RetentionSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  /// Currently selected retention period.
  final RetentionPeriod selected;

  /// Called when the user selects a new retention period.
  final ValueChanged<RetentionPeriod> onChanged;

  /// If true, shows a compact chip-style selector.
  final bool compact;

  /// Returns the color for a given retention period.
  static Color colorFor(RetentionPeriod period) {
    return switch (period) {
      RetentionPeriod.oneMinute => AppColors.error,
      RetentionPeriod.oneHour => AppColors.warning,
      RetentionPeriod.oneDay => AppColors.primary,
      RetentionPeriod.oneWeek => AppColors.info,
      RetentionPeriod.oneMonth => AppColors.success,
      RetentionPeriod.oneYear => AppColors.secondary,
      RetentionPeriod.tenYears => AppColors.secondaryLight,
      RetentionPeriod.hundredYears => AppColors.textSecondary,
    };
  }

  /// Returns an icon for a given retention period.
  static IconData iconFor(RetentionPeriod period) {
    return switch (period) {
      RetentionPeriod.oneMinute => Icons.timer_outlined,
      RetentionPeriod.oneHour => Icons.schedule_outlined,
      RetentionPeriod.oneDay => Icons.today_outlined,
      RetentionPeriod.oneWeek => Icons.date_range_outlined,
      RetentionPeriod.oneMonth => Icons.calendar_month_outlined,
      RetentionPeriod.oneYear => Icons.event_outlined,
      RetentionPeriod.tenYears => Icons.calendar_today_outlined,
      RetentionPeriod.hundredYears => Icons.all_inclusive,
    };
  }

  Future<void> _showPicker(BuildContext context) async {
    final result = await showModalBottomSheet<RetentionPeriod>(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RetentionPickerSheet(selected: selected),
    );
    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(selected);
    final icon = iconFor(selected);

    if (compact) {
      return InkWell(
        onTap: () => _showPicker(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                selected.label,
                style: AppTypography.labelSmall.copyWith(color: color),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 14, color: color),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Expires in: ',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                selected.label,
                style: AppTypography.labelMedium.copyWith(color: color),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for selecting a retention period.
class _RetentionPickerSheet extends StatelessWidget {
  const _RetentionPickerSheet({required this.selected});

  final RetentionPeriod selected;

  @override
  Widget build(BuildContext context) {
    // Calculate max height as 70% of screen
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Retention Period',
                    style: AppTypography.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Documents will be automatically deleted after this period',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable options
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: RetentionPeriod.values
                    .map((period) => _buildOption(context, period))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, RetentionPeriod period) {
    final isSelected = period == selected;
    final color = RetentionSelector.colorFor(period);
    final icon = RetentionSelector.iconFor(period);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        period.label,
        style: AppTypography.bodyMedium.copyWith(
          color: isSelected ? color : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        _getDescription(period),
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: color, size: 24)
          : null,
      onTap: () => Navigator.pop(context, period),
    );
  }

  String _getDescription(RetentionPeriod period) {
    return switch (period) {
      RetentionPeriod.oneMinute => 'For very temporary sharing',
      RetentionPeriod.oneHour => 'Quick sharing session',
      RetentionPeriod.oneDay => 'Default - good for most uses',
      RetentionPeriod.oneWeek => 'Short-term storage',
      RetentionPeriod.oneMonth => 'Medium-term storage',
      RetentionPeriod.oneYear => 'Long-term storage',
      RetentionPeriod.tenYears => 'Archive storage',
      RetentionPeriod.hundredYears => 'Permanent - never auto-deleted',
    };
  }
}
