import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Styled error dialog for AOwl.
class ErrorDialog extends StatelessWidget {
  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.primaryAction,
    this.primaryActionLabel,
    this.secondaryAction,
    this.secondaryActionLabel,
  });

  final String title;
  final String message;
  final String? details;
  final VoidCallback? primaryAction;
  final String? primaryActionLabel;
  final VoidCallback? secondaryAction;
  final String? secondaryActionLabel;

  /// Show an error dialog.
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String? details,
    VoidCallback? primaryAction,
    String? primaryActionLabel,
    VoidCallback? secondaryAction,
    String? secondaryActionLabel,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: secondaryAction != null,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        details: details,
        primaryAction: primaryAction,
        primaryActionLabel: primaryActionLabel,
        secondaryAction: secondaryAction,
        secondaryActionLabel: secondaryActionLabel,
      ),
    );
  }

  /// Show a simple error with just OK button.
  static Future<void> showSimple({
    required BuildContext context,
    required String title,
    required String message,
    String? details,
  }) {
    return show(
      context: context,
      title: title,
      message: message,
      details: details,
      primaryAction: () => Navigator.of(context).pop(),
      primaryActionLabel: 'OK',
    );
  }

  /// Show a retry/cancel dialog.
  static Future<bool> showRetry({
    required BuildContext context,
    required String title,
    required String message,
    String? details,
  }) async {
    bool shouldRetry = false;
    await show(
      context: context,
      title: title,
      message: message,
      details: details,
      primaryAction: () {
        shouldRetry = true;
        Navigator.of(context).pop();
      },
      primaryActionLabel: 'Retry',
      secondaryAction: () {
        Navigator.of(context).pop();
      },
      secondaryActionLabel: 'Cancel',
    );
    return shouldRetry;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error icon and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Message
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            // Details (collapsible)
            if (details != null) ...[
              const SizedBox(height: 12),
              _DetailsSection(details: details!),
            ],

            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (secondaryAction != null)
                  TextButton(
                    onPressed: secondaryAction,
                    child: Text(secondaryActionLabel ?? 'Cancel'),
                  ),
                if (secondaryAction != null) const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      primaryAction ?? () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.textPrimary,
                  ),
                  child: Text(primaryActionLabel ?? 'OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSection extends StatefulWidget {
  const _DetailsSection({required this.details});

  final String details;

  @override
  State<_DetailsSection> createState() => _DetailsSectionState();
}

class _DetailsSectionState extends State<_DetailsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_right_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                'Show details',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundInput,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              widget.details,
              style: AppTypography.codeSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Success dialog variant.
class SuccessDialog extends StatelessWidget {
  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.actionLabel,
  });

  final String title;
  final String message;
  final VoidCallback? action;
  final String? actionLabel;

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? action,
    String? actionLabel,
  }) {
    return showDialog(
      context: context,
      builder: (context) => SuccessDialog(
        title: title,
        message: message,
        action: action,
        actionLabel: actionLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTypography.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: action ?? () => Navigator.of(context).pop(),
                child: Text(actionLabel ?? 'Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
