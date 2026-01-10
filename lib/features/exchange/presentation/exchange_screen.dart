import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/animated_list_item.dart';
import '../../../shared/widgets/encrypted_content_viewer.dart';
import '../../../shared/widgets/progress_overlay.dart';
import '../../../domain/models/vault_entry.dart';
import '../providers/sync_provider.dart';
import '../providers/vault_provider.dart';
import '../providers/vault_state.dart';
import 'widgets/entry_tile.dart';
import 'widgets/new_share_card.dart';
import 'widgets/sync_status_card.dart';

/// Main exchange screen for sharing and viewing encrypted content.
class ExchangeScreen extends ConsumerStatefulWidget {
  const ExchangeScreen({super.key});

  @override
  ConsumerState<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends ConsumerState<ExchangeScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('[ExchangeScreen] initState() called');
    // Trigger initial sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[ExchangeScreen] Triggering initial sync');
      ref.read(syncStateProvider.notifier).sync();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(syncStateProvider.notifier).sync();
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultNotifierProvider);
    final currentVaultState = vaultState.valueOrNull;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SvgPicture.asset(
                'assets/logo/aowl_logo.svg',
                width: 32,
                height: 32,
              ),
            ),
            const SizedBox(width: 10),
            const Text('AOwl'),
          ],
        ),
        actions: [
          // Sync indicator
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SyncIndicator(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'lock':
                  _lockVault();
                case 'settings':
                  // Navigate to settings
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'lock',
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Lock Vault'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // Sync status card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: const SyncStatusCard()
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .slideY(begin: -0.1, end: 0, duration: 300.ms),
              ),
            ),

            // New share card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: const NewShareCard()
                    .animate()
                    .fadeIn(duration: 300.ms, delay: 100.ms)
                    .slideY(begin: 0.1, end: 0, duration: 300.ms, delay: 100.ms),
              ),
            ),

            // Recent entries header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Recent',
                      style: AppTypography.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // Navigate to history
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
              ),
            ),

            // Entries list
            vaultState.when(
              data: (state) => _buildEntriesList(state),
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: _ErrorState(
                  message: error.toString(),
                  onRetry: _onRefresh,
                ),
              ),
            ),

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
        ),
        // Progress overlay
        if (currentVaultState is VaultStateSyncing)
          ProgressOverlay(
            operation: currentVaultState.operation,
            message: currentVaultState.message ?? 'Processing...',
            progress: currentVaultState.progress,
          ),
      ],
    );
  }

  Widget _buildEntriesList(VaultState state) {
    final List<VaultEntry> entries;
    if (state is VaultStateSynced) {
      entries = state.index.entriesByDate;
    } else {
      entries = [];
    }

    if (entries.isEmpty) {
      return const SliverToBoxAdapter(
        child: _EmptyState(),
      );
    }

    // Show only recent entries (max 5)
    final recentEntries = entries.take(5).toList();

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: recentEntries.length,
        separatorBuilder: (_, i) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = recentEntries[index];
          return EntryTile(
            entry: entry,
            onTap: () => _viewEntry(entry),
            onDelete: () => _deleteEntry(entry),
          ).animateListItem(index);
        },
      ),
    );
  }

  void _viewEntry(VaultEntry entry) {
    EncryptedContentViewer.show(
      context: context,
      entry: entry,
    );
  }

  Future<void> _deleteEntry(VaultEntry entry) async {
    try {
      await ref.read(vaultNotifierProvider.notifier).deleteEntry(entry.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${entry.label}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // TODO: Implement undo
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _lockVault() {
    // TODO: Implement lock via auth provider
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundInput,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No shared content yet',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Share text or images above to get started.\nAll content is end-to-end encrypted.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
