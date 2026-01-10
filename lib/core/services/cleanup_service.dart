import 'package:flutter/foundation.dart';

import '../../features/exchange/domain/vault_index.dart';
import '../crypto/crypto_service.dart';
import '../github/vault_repository.dart';

/// Result of a cleanup operation.
class CleanupResult {
  /// Number of entries successfully deleted.
  final int deleted;

  /// Number of entries that failed to delete.
  final int failed;

  /// Number of entries remaining after this batch (if rate-limited).
  final int remaining;

  const CleanupResult({
    required this.deleted,
    required this.failed,
    required this.remaining,
  });

  factory CleanupResult.empty() => const CleanupResult(
        deleted: 0,
        failed: 0,
        remaining: 0,
      );

  bool get hasDeleted => deleted > 0;
  bool get hasFailed => failed > 0;
  bool get hasRemaining => remaining > 0;

  @override
  String toString() =>
      'CleanupResult(deleted: $deleted, failed: $failed, remaining: $remaining)';
}

/// Service for cleaning up expired vault entries.
class CleanupService {
  final VaultRepository _repository;
  final CryptoService _crypto;

  /// Maximum number of entries to delete per batch to avoid rate limits.
  static const int maxBatchSize = 50;

  CleanupService({
    required VaultRepository repository,
    required CryptoService crypto,
  })  : _repository = repository,
        _crypto = crypto;

  /// Cleans up expired entries from the vault.
  ///
  /// Returns a [CleanupResult] with the number of deleted, failed, and remaining entries.
  /// Limits deletion to [maxBatchSize] entries per call to avoid GitHub API rate limits.
  Future<CleanupResult> cleanupExpiredEntries({
    required VaultIndex index,
    required Uint8List masterKey,
    required String indexSha,
  }) async {
    final expired = index.expiredEntries;
    if (expired.isEmpty) {
      debugPrint('[CleanupService] No expired entries to clean up');
      return CleanupResult.empty();
    }

    debugPrint('[CleanupService] Found ${expired.length} expired entries');

    // Limit batch size for rate limits
    final batch = expired.take(maxBatchSize).toList();
    final remaining = expired.length - batch.length;

    debugPrint('[CleanupService] Processing batch of ${batch.length} entries, $remaining remaining');

    int deleted = 0;
    int failed = 0;
    final deletedIds = <String>[];

    for (final entry in batch) {
      try {
        debugPrint('[CleanupService] Deleting entry ${entry.id} (${entry.label})...');

        // Use the SHA stored in the entry, or fetch it if not available
        String? fileSha = entry.sha;
        if (fileSha == null) {
          debugPrint('[CleanupService] Entry ${entry.id} has no stored SHA, fetching...');
          final fileResult = await _repository.getFileInfo('${VaultRepository.dataDir}/${entry.id}.enc');
          if (fileResult.isFailure) {
            debugPrint('[CleanupService] Entry ${entry.id} not found on remote, marking as deleted');
            deletedIds.add(entry.id);
            deleted++;
            continue;
          }
          fileSha = fileResult.valueOrNull!.sha;
        }

        // Delete the file
        final deleteResult = await _repository.deleteEntry(
          entryId: entry.id,
          sha: fileSha,
        );

        if (deleteResult.isFailure) {
          debugPrint('[CleanupService] Failed to delete ${entry.id}: ${deleteResult.errorOrNull}');
          failed++;
          continue;
        }

        deletedIds.add(entry.id);
        deleted++;
        debugPrint('[CleanupService] Successfully deleted ${entry.id}');
      } catch (e) {
        debugPrint('[CleanupService] Error deleting ${entry.id}: $e');
        failed++;
      }
    }

    // Update index if any entries were deleted
    if (deletedIds.isNotEmpty) {
      debugPrint('[CleanupService] Updating index, removing ${deletedIds.length} entries');
      final updatedIndex = index.removeEntries(deletedIds);

      try {
        await _uploadIndex(updatedIndex, masterKey, indexSha);
        debugPrint('[CleanupService] Index updated successfully');
      } catch (e) {
        debugPrint('[CleanupService] Failed to update index: $e');
        // Don't count as failed since files are already deleted
      }
    }

    final result = CleanupResult(
      deleted: deleted,
      failed: failed,
      remaining: remaining,
    );

    debugPrint('[CleanupService] Cleanup completed: $result');
    return result;
  }

  Future<void> _uploadIndex(VaultIndex index, Uint8List masterKey, String currentSha) async {
    // Encrypt index
    final indexJson = index.toJsonString();
    final encryptResult = _crypto.encrypt(
      plaintext: Uint8List.fromList(indexJson.codeUnits),
      key: masterKey,
    );

    if (encryptResult.isFailure) {
      throw Exception('Failed to encrypt index');
    }

    final encryptedIndex = encryptResult.valueOrNull!;

    // Upload to GitHub
    final uploadResult = await _repository.uploadIndex(
      content: encryptedIndex,
      sha: currentSha,
    );

    if (uploadResult.isFailure) {
      throw Exception('Failed to upload index: ${uploadResult.errorOrNull}');
    }
  }
}
