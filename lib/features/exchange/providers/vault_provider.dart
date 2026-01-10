import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/github/github_auth.dart';
import '../../../core/github/github_errors.dart';
import '../../../core/github/vault_repository.dart';
import '../../../core/services/cleanup_service.dart';
import '../../../core/storage/local_cache_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/result.dart';
import '../../unlock/providers/auth_provider.dart';
import '../../unlock/providers/auth_state.dart';
import '../domain/vault_entry.dart';
import '../domain/vault_index.dart';
import 'vault_state.dart';

/// Provider for the local cache service.
final localCacheProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService();
});

/// Provider for the vault repository (GitHub API).
/// Note: This returns null because initialization is async and handled by VaultNotifier.
final vaultRepositoryProvider = Provider<VaultRepository?>((ref) {
  return null;
});

/// Provider for vault state management.
final vaultNotifierProvider =
    AsyncNotifierProvider<VaultNotifier, VaultState>(VaultNotifier.new);

/// Manages vault operations (sync, share, delete).
class VaultNotifier extends AsyncNotifier<VaultState> {
  late SecureStorageService _storage;
  late CryptoService _crypto;
  late LocalCacheService _cache;
  VaultRepository? _repository;
  Uint8List? _masterKey;

  @override
  FutureOr<VaultState> build() async {
    debugPrint('[VaultProvider] build() called');
    _storage = ref.read(secureStorageProvider);
    _crypto = ref.read(cryptoServiceProvider);
    _cache = ref.read(localCacheProvider);

    // Initialize cache
    await _cache.initialize();

    // Watch auth state for master key
    final authState = ref.watch(authNotifierProvider);
    debugPrint('[VaultProvider] Auth state: ${authState.value?.runtimeType}');
    if (authState.hasValue && authState.value is AuthStateUnlocked) {
      _masterKey = (authState.value as AuthStateUnlocked).masterKey;
      debugPrint('[VaultProvider] Master key obtained');
    } else {
      _masterKey = null;
      debugPrint('[VaultProvider] No master key, returning VaultStateIdle');
      return const VaultStateIdle();
    }

    // Initialize repository
    await _initRepository();
    debugPrint('[VaultProvider] Repository initialized, returning VaultStateIdle');

    return const VaultStateIdle();
  }

  Future<void> _initRepository() async {
    final token = await _storage.getGitHubToken();
    final owner = await _storage.getRepoOwner();
    final name = await _storage.getRepoName();

    if (token == null || owner == null || name == null) {
      _repository = null;
      return;
    }

    final auth = GitHubAuth(owner: owner, repo: name, token: token);
    _repository = VaultRepository(auth: auth);
  }

  /// Syncs the vault index from GitHub.
  Future<void> sync() async {
    debugPrint('[VaultProvider] sync() called');

    // Fix race condition: get master key from auth state if not set
    if (_masterKey == null) {
      final authState = ref.read(authNotifierProvider);
      if (authState.hasValue && authState.value is AuthStateUnlocked) {
        _masterKey = (authState.value as AuthStateUnlocked).masterKey;
        debugPrint('[VaultProvider] Master key obtained from auth state');
      }
    }

    // Initialize repository if needed
    if (_repository == null) {
      debugPrint('[VaultProvider] Repository null, initializing...');
      await _initRepository();
    }

    debugPrint('[VaultProvider] _masterKey is ${_masterKey == null ? 'null' : 'set'}');
    debugPrint('[VaultProvider] _repository is ${_repository == null ? 'null' : 'set'}');

    if (_masterKey == null) {
      debugPrint('[VaultProvider] No master key, setting error state');
      state = const AsyncValue.data(
        VaultStateError(VaultDecryptionError('Not authenticated')),
      );
      return;
    }

    if (_repository == null) {
      debugPrint('[VaultProvider] Repository still null after init, setting error state');
      state = const AsyncValue.data(VaultStateError(VaultNotInitializedError()));
      return;
    }

    debugPrint('[VaultProvider] Setting state to VaultStateSyncing (downloading)');
    state = const AsyncValue.data(VaultStateSyncing(
        message: 'Downloading index...',
        operation: SyncOperation.downloading,
      ));

    try {
      // Download encrypted index
      debugPrint('[VaultProvider] Downloading index from GitHub...');
      final indexResult = await _repository!.downloadIndex();
      debugPrint('[VaultProvider] Download result: ${indexResult.isSuccess ? 'success' : 'failure'}');

      if (indexResult.isFailure) {
        final error = (indexResult as Failure<Uint8List, GitHubError>).error;
        debugPrint('[VaultProvider] Download failed with error: $error');
        if (error is NotFound) {
          // Vault not initialized - create empty index
          debugPrint('[VaultProvider] Index not found, creating empty vault');
          state = AsyncValue.data(VaultStateSynced(
            index: VaultIndex.empty(),
            lastSyncAt: DateTime.now(),
          ));
          return;
        }
        debugPrint('[VaultProvider] Setting error state for download failure');
        state = AsyncValue.data(VaultStateError(_mapGitHubError(error)));
        return;
      }

      final encryptedIndex = (indexResult as Success<Uint8List, GitHubError>).value;
      debugPrint('[VaultProvider] Downloaded ${encryptedIndex.length} bytes');

      // Decrypt index
      debugPrint('[VaultProvider] Setting state to VaultStateSyncing (decrypting)');
      state = const AsyncValue.data(VaultStateSyncing(
        message: 'Decrypting...',
        operation: SyncOperation.decrypting,
      ));

      debugPrint('[VaultProvider] Decrypting index...');
      final decryptResult = _crypto.decrypt(
        encryptedData: encryptedIndex,
        key: _masterKey!,
      );

      if (decryptResult.isFailure) {
        debugPrint('[VaultProvider] Decryption failed, trying backup...');
        // Try backup
        final backup = _cache.getIndexBackup();
        if (backup != null) {
          try {
            final index = VaultIndex.fromJsonString(utf8.decode(backup));
            debugPrint('[VaultProvider] Backup restored successfully');
            state = AsyncValue.data(VaultStateSynced(
              index: index,
              lastSyncAt: DateTime.now(),
            ));
            return;
          } catch (e) {
            debugPrint('[VaultProvider] Backup restore also failed: $e');
            // Backup also failed
          }
        }
        debugPrint('[VaultProvider] Setting decryption error state');
        state = const AsyncValue.data(
          VaultStateError(VaultDecryptionError('Failed to decrypt index. Wrong password?')),
        );
        return;
      }

      final decryptedBytes = (decryptResult as Success<Uint8List, dynamic>).value;
      final jsonString = utf8.decode(decryptedBytes);
      debugPrint('[VaultProvider] Decrypted index JSON: ${jsonString.substring(0, jsonString.length > 100 ? 100 : jsonString.length)}...');
      final index = VaultIndex.fromJsonString(jsonString);
      debugPrint('[VaultProvider] Parsed index with ${index.count} entries');

      // Cache decrypted index as backup
      await _cache.cacheIndexBackup(decryptedBytes);

      // Get index SHA
      debugPrint('[VaultProvider] Getting index SHA...');
      final shaResult = await _repository!.getIndexSha();
      final sha = shaResult.isSuccess
          ? (shaResult as Success<String?, GitHubError>).value
          : null;
      debugPrint('[VaultProvider] Index SHA: $sha');

      // Update storage
      if (sha != null) {
        await _storage.setIndexSha(sha);
      }
      await _storage.setLastSyncAt(DateTime.now());

      debugPrint('[VaultProvider] Setting state to VaultStateSynced');
      state = AsyncValue.data(VaultStateSynced(
        index: index,
        indexSha: sha,
        lastSyncAt: DateTime.now(),
      ));
      debugPrint('[VaultProvider] sync() completed successfully');

      // Cleanup expired entries after sync
      await _cleanupExpiredEntries(index, sha);
    } catch (e, stack) {
      debugPrint('[VaultProvider] Exception during sync: $e');
      debugPrint('[VaultProvider] Stack: $stack');
      state = AsyncValue.data(VaultStateError(VaultNetworkError(e.toString())));
    }
  }

  /// Cleans up expired entries after sync.
  Future<void> _cleanupExpiredEntries(VaultIndex index, String? indexSha) async {
    if (_masterKey == null || _repository == null || indexSha == null) {
      debugPrint('[VaultProvider] Cannot cleanup: missing key, repo, or SHA');
      return;
    }

    // Check if there are expired entries
    final expired = index.expiredEntries;
    if (expired.isEmpty) {
      debugPrint('[VaultProvider] No expired entries to cleanup');
      return;
    }

    debugPrint('[VaultProvider] Found ${expired.length} expired entries, cleaning up...');

    try {
      final cleanupService = CleanupService(
        repository: _repository!,
        crypto: _crypto,
      );

      final result = await cleanupService.cleanupExpiredEntries(
        index: index,
        masterKey: _masterKey!,
        indexSha: indexSha,
      );

      if (result.hasDeleted) {
        debugPrint('[VaultProvider] Cleaned up ${result.deleted} expired entries');

        // Re-sync to get updated index
        await sync();
      }

      if (result.hasRemaining) {
        debugPrint('[VaultProvider] ${result.remaining} entries remaining for next cleanup');
      }
    } catch (e) {
      debugPrint('[VaultProvider] Cleanup error: $e');
      // Don't fail sync if cleanup fails
    }
  }

  /// Shares a text entry.
  Future<void> shareText({
    required String label,
    required String content,
    RetentionPeriod? retentionPeriod,
  }) async {
    await _shareEntry(
      type: EntryType.text,
      label: label,
      content: Uint8List.fromList(utf8.encode(content)),
      mimeType: 'text/plain',
      retentionPeriod: retentionPeriod,
    );
  }

  /// Shares an image entry.
  Future<void> shareImage({
    required String label,
    required Uint8List imageData,
    required String mimeType,
    RetentionPeriod? retentionPeriod,
  }) async {
    debugPrint('[VaultProvider] shareImage called: label="$label", size=${imageData.length}, mimeType=$mimeType');
    await _shareEntry(
      type: EntryType.image,
      label: label,
      content: imageData,
      mimeType: mimeType,
      retentionPeriod: retentionPeriod,
    );
    debugPrint('[VaultProvider] shareImage completed');
  }

  /// Shares an entry (internal implementation).
  Future<void> _shareEntry({
    required EntryType type,
    required String label,
    required Uint8List content,
    String? mimeType,
    RetentionPeriod? retentionPeriod,
  }) async {
    debugPrint('[VaultProvider] _shareEntry called: type=$type, label="$label", size=${content.length}');

    if (_masterKey == null || _repository == null) {
      debugPrint('[VaultProvider] _shareEntry: Not authenticated (_masterKey=${_masterKey == null ? 'null' : 'set'}, _repository=${_repository == null ? 'null' : 'set'})');
      state = const AsyncValue.data(
        VaultStateError(VaultDecryptionError('Not authenticated')),
      );
      return;
    }

    final currentState = state.valueOrNull;
    debugPrint('[VaultProvider] _shareEntry: currentState is ${currentState.runtimeType}');
    if (currentState is! VaultStateSynced) {
      debugPrint('[VaultProvider] _shareEntry: Vault not synced, returning error');
      state = const AsyncValue.data(
        VaultStateError(VaultNotInitializedError()),
      );
      return;
    }

    state = const AsyncValue.data(VaultStateSyncing(
        message: 'Encrypting...',
        operation: SyncOperation.encrypting,
      ));

    try {
      // Encrypt content
      final encryptResult = _crypto.encrypt(
        plaintext: content,
        key: _masterKey!,
      );

      if (encryptResult.isFailure) {
        state = const AsyncValue.data(
          VaultStateError(VaultDecryptionError('Encryption failed')),
        );
        return;
      }

      final encryptedContent = (encryptResult as Success<Uint8List, dynamic>).value;

      // Create entry
      final entry = VaultEntry.create(
        type: type,
        label: label,
        mimeType: mimeType,
        sizeBytes: encryptedContent.length,
        retentionPeriod: retentionPeriod,
      );

      state = const AsyncValue.data(VaultStateSyncing(
        message: 'Uploading...',
        operation: SyncOperation.uploading,
      ));

      // Upload encrypted file
      final uploadResult = await _repository!.uploadEntry(
        entryId: entry.id,
        content: encryptedContent,
      );

      if (uploadResult.isFailure) {
        final error = (uploadResult as Failure).error as GitHubError;
        state = AsyncValue.data(VaultStateError(_mapGitHubError(error)));
        return;
      }

      final uploadedFile = (uploadResult as Success).value;
      final entryWithSha = entry.withSha(uploadedFile.sha);

      // Update index
      final newIndex = currentState.index.addEntry(entryWithSha);

      // Upload updated index
      await _uploadIndex(newIndex, currentState.indexSha);
    } catch (e) {
      state = AsyncValue.data(VaultStateError(VaultNetworkError(e.toString())));
    }
  }

  /// Deletes an entry.
  Future<void> deleteEntry(String entryId) async {
    if (_masterKey == null || _repository == null) {
      return;
    }

    final currentState = state.valueOrNull;
    if (currentState is! VaultStateSynced) {
      return;
    }

    final entry = currentState.index.getEntry(entryId);
    if (entry == null) {
      state = AsyncValue.data(VaultStateError(VaultEntryNotFoundError(entryId)));
      return;
    }

    state = const AsyncValue.data(VaultStateSyncing(
        message: 'Deleting...',
        operation: SyncOperation.syncing,
      ));

    try {
      // Delete encrypted file
      if (entry.sha != null) {
        await _repository!.deleteEntry(entryId: entryId, sha: entry.sha!);
      }

      // Update index
      final newIndex = currentState.index.removeEntry(entryId);

      // Upload updated index
      await _uploadIndex(newIndex, currentState.indexSha);

      // Remove from cache
      await _cache.removeCachedEntry(entryId);
      await _cache.removeCachedEncryptedFile(entryId);
    } catch (e) {
      state = AsyncValue.data(VaultStateError(VaultNetworkError(e.toString())));
    }
  }

  /// Changes the retention period of an entry.
  Future<void> changeRetention(String entryId, RetentionPeriod newPeriod) async {
    if (_masterKey == null || _repository == null) {
      debugPrint('[VaultProvider] changeRetention: Not authenticated');
      return;
    }

    final currentState = state.valueOrNull;
    if (currentState is! VaultStateSynced) {
      debugPrint('[VaultProvider] changeRetention: Vault not synced');
      return;
    }

    final entry = currentState.index.getEntry(entryId);
    if (entry == null) {
      state = AsyncValue.data(VaultStateError(VaultEntryNotFoundError(entryId)));
      return;
    }

    debugPrint('[VaultProvider] changeRetention: Updating ${entry.label} to ${newPeriod.label}');

    state = const AsyncValue.data(VaultStateSyncing(
      message: 'Updating retention...',
      operation: SyncOperation.syncing,
    ));

    try {
      // Update entry with new retention period
      final updatedEntry = entry.copyWith(
        retentionPeriod: newPeriod,
        updatedAt: DateTime.now().toUtc(),
      );

      // Update index
      final newIndex = currentState.index.updateEntry(updatedEntry);

      // Upload updated index
      await _uploadIndex(newIndex, currentState.indexSha);

      debugPrint('[VaultProvider] changeRetention: Successfully updated');
    } catch (e) {
      debugPrint('[VaultProvider] changeRetention: Error $e');
      state = AsyncValue.data(VaultStateError(VaultNetworkError(e.toString())));
    }
  }

  /// Downloads and decrypts an entry's content.
  Future<Uint8List?> getEntryContent(String entryId) async {
    if (_masterKey == null || _repository == null) {
      return null;
    }

    // Check cache first
    final cached = _cache.getCachedEncryptedFile(entryId);
    if (cached != null) {
      final decryptResult = _crypto.decrypt(
        encryptedData: cached,
        key: _masterKey!,
      );
      if (decryptResult.isSuccess) {
        return (decryptResult as Success<Uint8List, dynamic>).value;
      }
    }

    // Download from GitHub
    final downloadResult = await _repository!.downloadEntry(entryId);
    if (downloadResult.isFailure) {
      return null;
    }

    final encrypted = (downloadResult as Success<Uint8List, GitHubError>).value;

    // Cache encrypted content
    await _cache.cacheEncryptedFile(entryId, encrypted);

    // Decrypt
    final decryptResult = _crypto.decrypt(
      encryptedData: encrypted,
      key: _masterKey!,
    );

    if (decryptResult.isFailure) {
      return null;
    }

    return (decryptResult as Success<Uint8List, dynamic>).value;
  }

  /// Uploads the updated index.
  Future<void> _uploadIndex(VaultIndex index, String? currentSha) async {
    state = const AsyncValue.data(VaultStateSyncing(
        message: 'Updating index...',
        operation: SyncOperation.uploading,
      ));

    // Encrypt index
    final jsonString = index.toJsonString();
    final encryptResult = _crypto.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(jsonString)),
      key: _masterKey!,
    );

    if (encryptResult.isFailure) {
      state = const AsyncValue.data(
        VaultStateError(VaultDecryptionError('Failed to encrypt index')),
      );
      return;
    }

    final encrypted = (encryptResult as Success<Uint8List, dynamic>).value;

    // Upload
    final uploadResult = await _repository!.uploadIndex(
      content: encrypted,
      sha: currentSha,
    );

    if (uploadResult.isFailure) {
      final error = (uploadResult as Failure).error as GitHubError;
      if (error is ConflictError) {
        state = const AsyncValue.data(
          VaultStateError(VaultConflictError('Index was modified. Please sync and try again.')),
        );
        return;
      }
      state = AsyncValue.data(VaultStateError(_mapGitHubError(error)));
      return;
    }

    final newSha = (uploadResult as Success).value.sha;

    // Cache backup
    await _cache.cacheIndexBackup(Uint8List.fromList(utf8.encode(jsonString)));

    // Update state
    await _storage.setIndexSha(newSha);
    await _storage.setLastSyncAt(DateTime.now());

    state = AsyncValue.data(VaultStateSynced(
      index: index,
      indexSha: newSha,
      lastSyncAt: DateTime.now(),
    ));
  }

  VaultError _mapGitHubError(GitHubError error) {
    return switch (error) {
      AuthenticationFailed() => const VaultGitHubError('Authentication failed'),
      NotFound(:final path) => VaultGitHubError('Not found: $path'),
      ConflictError() => const VaultConflictError('Concurrent modification'),
      RateLimitExceeded(:final resetAt) => VaultRateLimitError(
          resetAt?.difference(DateTime.now()),
        ),
      AccessForbidden() => const VaultGitHubError('Access forbidden'),
      NetworkError(:final details) => VaultNetworkError(details),
      ServerError(:final statusCode) => VaultGitHubError('Server error: $statusCode'),
      UnknownGitHubError(:final details) => VaultGitHubError(details),
    };
  }
}
