import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Keys for Hive boxes.
abstract class CacheBoxNames {
  static const String entries = 'entries_cache';
  static const String metadata = 'metadata_cache';
}

/// Service for caching data locally using Hive.
///
/// Caches:
/// - Decrypted entry metadata (for offline access)
/// - Downloaded .enc file contents
class LocalCacheService {
  Box<Map>? _entriesBox;
  Box<Uint8List>? _metadataBox;
  bool _initialized = false;
  bool _initializationFailed = false;
  String? _cachePath;

  /// Initializes Hive and opens boxes.
  Future<void> initialize() async {
    if (_initialized) return;
    if (_initializationFailed) return; // Don't retry if already failed

    final dir = await getApplicationDocumentsDirectory();
    _cachePath = '${dir.path}/aowl_cache';

    try {
      await Hive.initFlutter(_cachePath!);
      _entriesBox = await Hive.openBox<Map>(CacheBoxNames.entries);
      _metadataBox = await Hive.openBox<Uint8List>(CacheBoxNames.metadata);
      _initialized = true;
      debugPrint('[LocalCache] Initialized successfully');
    } catch (e) {
      debugPrint('[LocalCache] Error during initialization: $e');

      // Try to delete lock files and retry
      if (e is FileSystemException && e.message.contains('lock failed')) {
        debugPrint('[LocalCache] Attempting to clear stale lock files...');
        await _clearLockFiles();

        try {
          _entriesBox = await Hive.openBox<Map>(CacheBoxNames.entries);
          _metadataBox = await Hive.openBox<Uint8List>(CacheBoxNames.metadata);
          _initialized = true;
          debugPrint('[LocalCache] Initialized successfully after clearing locks');
          return;
        } catch (e2) {
          debugPrint('[LocalCache] Retry failed: $e2');
        }
      }

      // Fall back to no-op mode - cache will just not work
      _initializationFailed = true;
      debugPrint('[LocalCache] Falling back to no-op mode (cache disabled)');
    }
  }

  /// Clears stale lock files.
  Future<void> _clearLockFiles() async {
    if (_cachePath == null) return;
    try {
      final entriesLock = File('$_cachePath/${CacheBoxNames.entries}.lock');
      final metadataLock = File('$_cachePath/${CacheBoxNames.metadata}.lock');
      if (await entriesLock.exists()) await entriesLock.delete();
      if (await metadataLock.exists()) await metadataLock.delete();
      debugPrint('[LocalCache] Lock files cleared');
    } catch (e) {
      debugPrint('[LocalCache] Error clearing lock files: $e');
    }
  }

  /// Checks if the service is available.
  bool get isAvailable => _initialized && !_initializationFailed;

  /// Ensures the service is initialized.
  /// Returns false if cache is not available (will be no-op).
  bool _ensureInitialized() {
    if (_initializationFailed) {
      return false; // No-op mode
    }
    if (!_initialized) {
      debugPrint('[LocalCache] WARNING: Not initialized, operations will be skipped');
      return false;
    }
    return true;
  }

  // ============ Entry Cache ============

  /// Caches entry metadata.
  Future<void> cacheEntry(String id, Map<String, dynamic> data) async {
    if (!_ensureInitialized()) return;
    await _entriesBox!.put(id, data);
  }

  /// Retrieves cached entry metadata.
  Map<String, dynamic>? getCachedEntry(String id) {
    if (!_ensureInitialized()) return null;
    final data = _entriesBox!.get(id);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  /// Retrieves all cached entries.
  Map<String, Map<String, dynamic>> getAllCachedEntries() {
    if (!_ensureInitialized()) return {};
    final result = <String, Map<String, dynamic>>{};
    for (final key in _entriesBox!.keys) {
      final data = _entriesBox!.get(key);
      if (data != null) {
        result[key as String] = Map<String, dynamic>.from(data);
      }
    }
    return result;
  }

  /// Removes a cached entry.
  Future<void> removeCachedEntry(String id) async {
    if (!_ensureInitialized()) return;
    await _entriesBox!.delete(id);
  }

  /// Clears all cached entries.
  Future<void> clearEntryCache() async {
    if (!_ensureInitialized()) return;
    await _entriesBox!.clear();
  }

  // ============ Encrypted File Cache ============

  /// Caches encrypted file content.
  Future<void> cacheEncryptedFile(String entryId, Uint8List content) async {
    if (!_ensureInitialized()) return;
    await _metadataBox!.put(entryId, content);
  }

  /// Retrieves cached encrypted file content.
  Uint8List? getCachedEncryptedFile(String entryId) {
    if (!_ensureInitialized()) return null;
    return _metadataBox!.get(entryId);
  }

  /// Removes cached encrypted file.
  Future<void> removeCachedEncryptedFile(String entryId) async {
    if (!_ensureInitialized()) return;
    await _metadataBox!.delete(entryId);
  }

  /// Clears all cached encrypted files.
  Future<void> clearEncryptedFileCache() async {
    if (!_ensureInitialized()) return;
    await _metadataBox!.clear();
  }

  // ============ Index Backup ============

  /// Caches the decrypted index as a backup.
  Future<void> cacheIndexBackup(Uint8List decryptedIndex) async {
    if (!_ensureInitialized()) return;
    await _metadataBox!.put('_index_backup', decryptedIndex);
  }

  /// Retrieves the cached index backup.
  Uint8List? getIndexBackup() {
    if (!_ensureInitialized()) return null;
    return _metadataBox!.get('_index_backup');
  }

  /// Removes the index backup.
  Future<void> clearIndexBackup() async {
    if (!_ensureInitialized()) return;
    await _metadataBox!.delete('_index_backup');
  }

  // ============ Cleanup ============

  /// Clears all cached data.
  Future<void> clearAll() async {
    if (!_ensureInitialized()) return;
    await _entriesBox!.clear();
    await _metadataBox!.clear();
  }

  /// Closes the Hive boxes.
  Future<void> close() async {
    if (!_initialized) return;
    await _entriesBox?.close();
    await _metadataBox?.close();
    _initialized = false;
  }

  /// Gets the total cache size in bytes.
  int get cacheSize {
    if (!_initialized) return 0;
    var size = 0;
    for (final key in _metadataBox!.keys) {
      final data = _metadataBox!.get(key);
      if (data != null) {
        size += data.length;
      }
    }
    return size;
  }

  /// Gets the number of cached entries.
  int get cachedEntryCount {
    if (!_initialized) return 0;
    return _entriesBox!.length;
  }
}
