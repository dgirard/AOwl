import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/encrypted_content_viewer.dart';
import '../../exchange/domain/vault_entry.dart';
import '../../exchange/presentation/widgets/entry_tile.dart';
import '../../exchange/providers/sync_provider.dart';
import '../../exchange/providers/vault_provider.dart';
import '../../exchange/providers/vault_state.dart';

/// Filter options for history screen.
enum HistoryFilter {
  all('All'),
  text('Text'),
  image('Images');

  const HistoryFilter(this.label);
  final String label;
}

/// History screen showing all vault entries with filters.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryFilter _filter = HistoryFilter.all;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(syncStateProvider.notifier).sync();
  }

  List<VaultEntry> _filterEntries(List<VaultEntry> entries) {
    var filtered = entries;

    // Apply type filter
    filtered = switch (_filter) {
      HistoryFilter.all => filtered,
      HistoryFilter.text => filtered.where((e) => e.isText).toList(),
      HistoryFilter.image => filtered.where((e) => e.isImage).toList(),
    };

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((e) => e.label.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault History'),
      ),
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search entries...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: HistoryFilter.values.map((filter) {
                      final isSelected = _filter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(filter.label),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _filter = filter),
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Entries list
          Expanded(
            child: vaultState.when(
              data: (state) => _buildEntriesList(state),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: _onRefresh,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(VaultState state) {
    final List<VaultEntry> allEntries;
    if (state is VaultStateSynced) {
      allEntries = state.index.entriesByDate;
    } else {
      allEntries = [];
    }

    final entries = _filterEntries(allEntries);

    if (entries.isEmpty) {
      return _buildEmptyState(allEntries.isEmpty);
    }

    // Group entries by date
    final groupedEntries = _groupByDate(entries);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groupedEntries.length,
        itemBuilder: (context, index) {
          final group = groupedEntries[index];
          return _DateGroup(
            date: group.date,
            entries: group.entries,
            onEntryTap: _viewEntry,
            onEntryDelete: _deleteEntry,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isVaultEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVaultEmpty
                  ? Icons.folder_open_outlined
                  : Icons.search_off_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              isVaultEmpty ? 'Vault is empty' : 'No matching entries',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isVaultEmpty
                  ? 'Share something to get started'
                  : 'Try adjusting your filters',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DateGroupData> _groupByDate(List<VaultEntry> entries) {
    final groups = <String, List<VaultEntry>>{};

    for (final entry in entries) {
      final dateKey = _getDateKey(entry.updatedAt);
      groups.putIfAbsent(dateKey, () => []).add(entry);
    }

    return groups.entries
        .map((e) => _DateGroupData(date: e.key, entries: e.value))
        .toList();
  }

  String _getDateKey(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${time.month}/${time.day}/${time.year}';
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
}

class _DateGroupData {
  const _DateGroupData({required this.date, required this.entries});
  final String date;
  final List<VaultEntry> entries;
}

class _DateGroup extends StatelessWidget {
  const _DateGroup({
    required this.date,
    required this.entries,
    required this.onEntryTap,
    required this.onEntryDelete,
  });

  final String date;
  final List<VaultEntry> entries;
  final void Function(VaultEntry) onEntryTap;
  final void Function(VaultEntry) onEntryDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            date,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EntryTile(
                entry: entry,
                showSha: true,
                onTap: () => onEntryTap(entry),
                onDelete: () => onEntryDelete(entry),
              ),
            )),
      ],
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
    return Center(
      child: Padding(
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
              'Failed to load history',
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
      ),
    );
  }
}
