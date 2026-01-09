import '../domain/vault_index.dart';

/// Sealed hierarchy of vault states.
sealed class VaultState {
  const VaultState();
}

/// Initial state - vault not loaded.
final class VaultStateIdle extends VaultState {
  const VaultStateIdle();

  @override
  String toString() => 'VaultStateIdle';
}

/// Loading/syncing state.
final class VaultStateSyncing extends VaultState {
  final String? message;
  final double? progress;
  final SyncOperation operation;

  const VaultStateSyncing({
    this.message,
    this.progress,
    this.operation = SyncOperation.syncing,
  });

  @override
  String toString() => 'VaultStateSyncing($message, $progress)';
}

/// Types of sync operations for progress tracking.
enum SyncOperation {
  syncing,
  encrypting,
  decrypting,
  uploading,
  downloading,
}

/// Vault loaded and synced.
final class VaultStateSynced extends VaultState {
  /// The current vault index.
  final VaultIndex index;

  /// SHA of the current index on GitHub.
  final String? indexSha;

  /// Last sync timestamp.
  final DateTime lastSyncAt;

  const VaultStateSynced({
    required this.index,
    this.indexSha,
    required this.lastSyncAt,
  });

  @override
  String toString() => 'VaultStateSynced(${index.count} entries, sha: ${indexSha?.substring(0, 7)})';
}

/// Vault error state.
final class VaultStateError extends VaultState {
  final VaultError error;

  const VaultStateError(this.error);

  @override
  String toString() => 'VaultStateError($error)';
}

/// Sealed hierarchy of vault errors.
sealed class VaultError {
  const VaultError();

  String get message;
}

/// Network error during sync.
final class VaultNetworkError extends VaultError {
  final String details;

  const VaultNetworkError(this.details);

  @override
  String get message => 'Network error: $details';

  @override
  String toString() => 'VaultNetworkError($details)';
}

/// GitHub API error.
final class VaultGitHubError extends VaultError {
  final String details;

  const VaultGitHubError(this.details);

  @override
  String get message => 'GitHub error: $details';

  @override
  String toString() => 'VaultGitHubError($details)';
}

/// Decryption failed (wrong key or corrupted data).
final class VaultDecryptionError extends VaultError {
  final String details;

  const VaultDecryptionError(this.details);

  @override
  String get message => 'Decryption failed: $details';

  @override
  String toString() => 'VaultDecryptionError($details)';
}

/// Conflict during sync (concurrent modification).
final class VaultConflictError extends VaultError {
  final String details;

  const VaultConflictError(this.details);

  @override
  String get message => 'Sync conflict: $details';

  @override
  String toString() => 'VaultConflictError($details)';
}

/// Rate limit exceeded.
final class VaultRateLimitError extends VaultError {
  final Duration? retryAfter;

  const VaultRateLimitError([this.retryAfter]);

  @override
  String get message {
    if (retryAfter != null) {
      return 'Rate limit exceeded. Try again in ${retryAfter!.inMinutes} minutes.';
    }
    return 'Rate limit exceeded. Please try again later.';
  }

  @override
  String toString() => 'VaultRateLimitError($retryAfter)';
}

/// Vault not initialized on GitHub.
final class VaultNotInitializedError extends VaultError {
  const VaultNotInitializedError();

  @override
  String get message => 'Vault not initialized. Please set up the vault first.';

  @override
  String toString() => 'VaultNotInitializedError';
}

/// Entry not found.
final class VaultEntryNotFoundError extends VaultError {
  final String entryId;

  const VaultEntryNotFoundError(this.entryId);

  @override
  String get message => 'Entry not found: $entryId';

  @override
  String toString() => 'VaultEntryNotFoundError($entryId)';
}
