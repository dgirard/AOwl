import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Full-screen loading overlay with optional message.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message,
    this.progress,
  });

  /// Optional message to display below the spinner.
  final String? message;

  /// Optional progress value (0.0 to 1.0) for determinate progress.
  final double? progress;

  /// Show a loading overlay as a modal barrier.
  static Future<T> show<T>({
    required BuildContext context,
    required Future<T> Function() task,
    String? message,
  }) async {
    final overlay = OverlayEntry(
      builder: (context) => LoadingOverlay(message: message),
    );

    Overlay.of(context).insert(overlay);

    try {
      return await task();
    } finally {
      overlay.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.overlay,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (progress != null)
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  color: AppColors.primary,
                  backgroundColor: AppColors.backgroundInput,
                )
              else
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              if (message != null) ...[
                const SizedBox(height: 24),
                Text(
                  message!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A widget that wraps content and shows loading overlay when [isLoading] is true.
class LoadingWrapper extends StatelessWidget {
  const LoadingWrapper({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.progress,
  });

  final bool isLoading;
  final Widget child;
  final String? message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          LoadingOverlay(
            message: message,
            progress: progress,
          ),
      ],
    );
  }
}
