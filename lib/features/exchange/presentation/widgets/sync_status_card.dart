import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../providers/sync_provider.dart';

/// Displays the current sync status with GitHub.
class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);

    return _SyncStatusContent(state: syncState);
  }
}

class _SyncStatusContent extends StatelessWidget {
  const _SyncStatusContent({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle) = _getStatusInfo();
    final isSyncing = state.status == SyncStatus.syncing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          // Status icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isSyncing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),

          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Sync button
          if (!isSyncing)
            Consumer(
              builder: (context, ref, _) => IconButton(
                onPressed: () {
                  ref.read(syncStateProvider.notifier).sync();
                },
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Sync now',
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  (IconData, Color, String, String) _getStatusInfo() {
    return switch (state.status) {
      SyncStatus.idle => (
          Icons.cloud_done_outlined,
          AppColors.success,
          'Ready',
          state.lastSyncAt != null
              ? _formatLastSync(state.lastSyncAt!)
              : 'Not synced yet',
        ),
      SyncStatus.syncing => (
          Icons.cloud_sync_outlined,
          AppColors.syncing,
          'Syncing...',
          state.message ?? 'Connecting...',
        ),
      SyncStatus.synced => (
          Icons.cloud_done_outlined,
          AppColors.success,
          'Up to date',
          state.lastSyncAt != null
              ? _formatLastSync(state.lastSyncAt!)
              : 'Just synced',
        ),
      SyncStatus.error => (
          Icons.cloud_off_outlined,
          AppColors.error,
          state.hasConflict ? 'Conflict detected' : 'Sync failed',
          state.message ?? 'Unknown error',
        ),
      SyncStatus.offline => (
          Icons.cloud_off_outlined,
          AppColors.textTertiary,
          'Offline',
          'Check your connection',
        ),
    };
  }

  String _formatLastSync(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Compact sync indicator for app bar or other tight spaces.
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);

    final (icon, color) = switch (syncState.status) {
      SyncStatus.idle => (Icons.cloud_done_outlined, AppColors.success),
      SyncStatus.syncing => (Icons.cloud_sync_outlined, AppColors.syncing),
      SyncStatus.synced => (Icons.cloud_done_outlined, AppColors.success),
      SyncStatus.error => (Icons.cloud_off_outlined, AppColors.error),
      SyncStatus.offline => (Icons.cloud_off_outlined, AppColors.textTertiary),
    };

    if (syncState.status == SyncStatus.syncing) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color,
        ),
      );
    }

    return Icon(icon, color: color, size: 20);
  }
}
