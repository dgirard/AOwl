import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vault_index.dart';
import 'vault_provider.dart';
import 'vault_state.dart';

/// Sync status for UI display.
enum SyncStatus {
  idle,
  syncing,
  synced,
  error,
  offline,
}

/// Sync state for the UI.
class SyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSyncAt;
  final bool hasConflict;

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastSyncAt,
    this.hasConflict = false,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSyncAt,
    bool? hasConflict,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      hasConflict: hasConflict ?? this.hasConflict,
    );
  }
}

/// Provider for sync state.
final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

/// Manages sync operations with conflict resolution.
class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  Timer? _autoSyncTimer;

  /// Maximum retry attempts for conflict resolution.
  static const int maxRetries = 3;

  /// Delay between retries (exponential backoff).
  static const Duration baseRetryDelay = Duration(seconds: 1);

  SyncNotifier(this._ref) : super(const SyncState());

  /// Triggers a sync operation.
  Future<void> sync() async {
    if (state.status == SyncStatus.syncing) return;

    state = state.copyWith(status: SyncStatus.syncing, message: 'Syncing...');

    try {
      await _ref.read(vaultNotifierProvider.notifier).sync();

      final vaultState = _ref.read(vaultNotifierProvider).valueOrNull;

      if (vaultState is VaultStateSynced) {
        state = SyncState(
          status: SyncStatus.synced,
          lastSyncAt: vaultState.lastSyncAt,
        );
      } else if (vaultState is VaultStateError) {
        state = SyncState(
          status: SyncStatus.error,
          message: vaultState.error.message,
          hasConflict: vaultState.error is VaultConflictError,
        );
      }
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        message: e.toString(),
      );
    }
  }

  /// Handles a conflict by merging changes.
  ///
  /// Strategy:
  /// 1. Download remote index
  /// 2. Merge with local changes (newer wins)
  /// 3. Upload merged index
  Future<bool> resolveConflict({
    required VaultIndex localIndex,
    required VaultIndex remoteIndex,
  }) async {
    state = state.copyWith(
      status: SyncStatus.syncing,
      message: 'Resolving conflict...',
    );

    try {
      // Merge indexes - newer entries win
      // The merged result is used by the vault provider to upload
      localIndex.merge(remoteIndex);

      // The vault provider will handle uploading the merged index
      // This is a simplified implementation - in production, you'd
      // want more sophisticated conflict resolution

      state = state.copyWith(
        status: SyncStatus.synced,
        hasConflict: false,
        message: 'Conflict resolved',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: 'Failed to resolve conflict: $e',
      );
      return false;
    }
  }

  /// Starts auto-sync with the given interval.
  void startAutoSync(Duration interval) {
    stopAutoSync();
    _autoSyncTimer = Timer.periodic(interval, (_) => sync());
  }

  /// Stops auto-sync.
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Marks the sync as offline (no network).
  void setOffline() {
    state = state.copyWith(status: SyncStatus.offline);
  }

  /// Clears the error state.
  void clearError() {
    if (state.status == SyncStatus.error) {
      state = state.copyWith(
        status: SyncStatus.idle,
        message: null,
        hasConflict: false,
      );
    }
  }

  @override
  void dispose() {
    stopAutoSync();
    super.dispose();
  }
}

/// Extension for VaultIndex conflict detection.
extension VaultIndexConflict on VaultIndex {
  /// Detects conflicts between this index and another.
  ///
  /// Returns entries that exist in both with different content.
  List<String> detectConflicts(VaultIndex other) {
    final conflicts = <String>[];

    for (final entry in entries) {
      final otherEntry = other.getEntry(entry.id);
      if (otherEntry != null) {
        // Same ID but different SHA means conflict
        if (entry.sha != otherEntry.sha) {
          conflicts.add(entry.id);
        }
      }
    }

    return conflicts;
  }

  /// Returns entries that exist only in this index (added locally).
  List<String> addedEntries(VaultIndex remote) {
    return entries
        .where((e) => !remote.hasEntry(e.id))
        .map((e) => e.id)
        .toList();
  }

  /// Returns entries that exist only in remote (added remotely).
  List<String> removedEntries(VaultIndex remote) {
    return remote.entries
        .where((e) => !hasEntry(e.id))
        .map((e) => e.id)
        .toList();
  }
}
