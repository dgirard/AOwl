import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/github/github_auth.dart';
import '../../../core/github/github_errors.dart';
import '../../../core/github/vault_repository.dart';
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
    _storage = ref.read(secureStorageProvider);
    _crypto = ref.read(cryptoServiceProvider);
    _cache = ref.read(localCacheProvider);

    // Initialize cache
    await _cache.initialize();

    // Watch auth state for master key
    final authState = ref.watch(authNotifierProvider);
    if (authState.hasValue && authState.value is AuthStateUnlocked) {
      _masterKey = (authState.value as AuthStateUnlocked).masterKey;
    } else {
      _masterKey = null;
      return const VaultStateIdle();
    }

    // Initialize repository
    await _initRepository();

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
    if (_masterKey == null) {
      state = const AsyncValue.data(
        VaultStateError(VaultDecryptionError('Not authenticated')),
      );
      return;
    }

    if (_repository == null) {
      await _initRepository();
      if (_repository == null) {
        state = const AsyncValue.data(VaultStateError(VaultNotInitializedError()));
        return;
      }
    }

    state = const AsyncValue.data(VaultStateSyncing(
        message: 'Downloading index...',
        operation: SyncOperation.downloading,
      ));

    try {
      // Download encrypted index
      final indexResult = await _repository!.downloadIndex();

      if (indexResult.isFailure) {
        final error = (indexResult as Failure<Uint8List, GitHubError>).error;
        if (error is NotFound) {
          // Vault not initialized - create empty index
          state = AsyncValue.data(VaultStateSynced(
            index: VaultIndex.empty(),
            lastSyncAt: DateTime.now(),
          ));
          return;
        }
        state = AsyncValue.data(VaultStateError(_mapGitHubError(error)));
        return;
      }

      final encryptedIndex = (indexResult as Success<Uint8List, GitHubError>).value;

      // Decrypt index
      state = const AsyncValue.data(VaultStateSyncing(
        message: 'Decrypting...',
        operation: SyncOperation.decrypting,
      ));

      final decryptResult = _crypto.decrypt(
        encryptedData: encryptedIndex,
        key: _masterKey!,
      );

      if (decryptResult.isFailure) {
        // Try backup
        final backup = _cache.getIndexBackup();
        if (backup != null) {
          try {
            final index = VaultIndex.fromJsonString(utf8.decode(backup));
            state = AsyncValue.data(VaultStateSynced(
              index: index,
              lastSyncAt: DateTime.now(),
            ));
            return;
          } catch (_) {
            // Backup also failed
          }
        }
        state = const AsyncValue.data(
          VaultStateError(VaultDecryptionError('Failed to decrypt index. Wrong password?')),
        );
        return;
      }

      final decryptedBytes = (decryptResult as Success<Uint8List, dynamic>).value;
      final jsonString = utf8.decode(decryptedBytes);
      final index = VaultIndex.fromJsonString(jsonString);

      // Cache decrypted index as backup
      await _cache.cacheIndexBackup(decryptedBytes);

      // Get index SHA
      final shaResult = await _repository!.getIndexSha();
      final sha = shaResult.isSuccess
          ? (shaResult as Success<String?, GitHubError>).value
          : null;

      // Update storage
      if (sha != null) {
        await _storage.setIndexSha(sha);
      }
      await _storage.setLastSyncAt(DateTime.now());

      state = AsyncValue.data(VaultStateSynced(
        index: index,
        indexSha: sha,
        lastSyncAt: DateTime.now(),
      ));
    } catch (e) {
      state = AsyncValue.data(VaultStateError(VaultNetworkError(e.toString())));
    }
  }

  /// Shares a text entry.
  Future<void> shareText({
    required String label,
    required String content,
  }) async {
    await _shareEntry(
      type: EntryType.text,
      label: label,
      content: Uint8List.fromList(utf8.encode(content)),
      mimeType: 'text/plain',
    );
  }

  /// Shares an image entry.
  Future<void> shareImage({
    required String label,
    required Uint8List imageData,
    required String mimeType,
  }) async {
    await _shareEntry(
      type: EntryType.image,
      label: label,
      content: imageData,
      mimeType: mimeType,
    );
  }

  /// Shares an entry (internal implementation).
  Future<void> _shareEntry({
    required EntryType type,
    required String label,
    required Uint8List content,
    String? mimeType,
  }) async {
    if (_masterKey == null || _repository == null) {
      state = const AsyncValue.data(
        VaultStateError(VaultDecryptionError('Not authenticated')),
      );
      return;
    }

    final currentState = state.valueOrNull;
    if (currentState is! VaultStateSynced) {
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
