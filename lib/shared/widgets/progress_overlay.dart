import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../features/exchange/providers/vault_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Animated progress overlay for vault operations.
class ProgressOverlay extends StatelessWidget {
  const ProgressOverlay({
    super.key,
    required this.operation,
    required this.message,
    this.progress,
  });

  final SyncOperation operation;
  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.overlay,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAnimatedIcon(),
              const SizedBox(height: 20),
              Text(
                message,
                style: AppTypography.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (progress != null) ...[
                const SizedBox(height: 16),
                _buildProgressBar(),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 200.ms).scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              duration: 200.ms,
              curve: Curves.easeOut,
            ),
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    final (icon, color) = switch (operation) {
      SyncOperation.syncing => (Icons.cloud_sync_outlined, AppColors.syncing),
      SyncOperation.encrypting => (Icons.lock_outline, AppColors.primary),
      SyncOperation.decrypting => (Icons.lock_open_outlined, AppColors.primary),
      SyncOperation.uploading => (Icons.cloud_upload_outlined, AppColors.syncing),
      SyncOperation.downloading => (Icons.cloud_download_outlined, AppColors.syncing),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 48,
        color: color,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1500.ms, color: color.withValues(alpha: 0.3));
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.backgroundInput,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress! * 100).toInt()}%',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Extension to show progress overlay for vault operations.
extension VaultStateProgress on VaultState {
  bool get isOperating => this is VaultStateSyncing;

  String get operationMessage {
    if (this is VaultStateSyncing) {
      return (this as VaultStateSyncing).message ?? 'Processing...';
    }
    return '';
  }

  double? get operationProgress {
    if (this is VaultStateSyncing) {
      return (this as VaultStateSyncing).progress;
    }
    return null;
  }

  SyncOperation get currentOperation {
    if (this is VaultStateSyncing) {
      return (this as VaultStateSyncing).operation;
    }
    return SyncOperation.syncing;
  }
}
