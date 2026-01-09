import 'dart:typed_data';

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

  /// Initializes Hive and opens boxes.
  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter('${dir.path}/ashare_cache');

    _entriesBox = await Hive.openBox<Map>(CacheBoxNames.entries);
    _metadataBox = await Hive.openBox<Uint8List>(CacheBoxNames.metadata);

    _initialized = true;
  }

  /// Ensures the service is initialized.
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('LocalCacheService not initialized. Call initialize() first.');
    }
  }

  // ============ Entry Cache ============

  /// Caches entry metadata.
  Future<void> cacheEntry(String id, Map<String, dynamic> data) async {
    _ensureInitialized();
    await _entriesBox!.put(id, data);
  }

  /// Retrieves cached entry metadata.
  Map<String, dynamic>? getCachedEntry(String id) {
    _ensureInitialized();
    final data = _entriesBox!.get(id);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  /// Retrieves all cached entries.
  Map<String, Map<String, dynamic>> getAllCachedEntries() {
    _ensureInitialized();
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
    _ensureInitialized();
    await _entriesBox!.delete(id);
  }

  /// Clears all cached entries.
  Future<void> clearEntryCache() async {
    _ensureInitialized();
    await _entriesBox!.clear();
  }

  // ============ Encrypted File Cache ============

  /// Caches encrypted file content.
  Future<void> cacheEncryptedFile(String entryId, Uint8List content) async {
    _ensureInitialized();
    await _metadataBox!.put(entryId, content);
  }

  /// Retrieves cached encrypted file content.
  Uint8List? getCachedEncryptedFile(String entryId) {
    _ensureInitialized();
    return _metadataBox!.get(entryId);
  }

  /// Removes cached encrypted file.
  Future<void> removeCachedEncryptedFile(String entryId) async {
    _ensureInitialized();
    await _metadataBox!.delete(entryId);
  }

  /// Clears all cached encrypted files.
  Future<void> clearEncryptedFileCache() async {
    _ensureInitialized();
    await _metadataBox!.clear();
  }

  // ============ Index Backup ============

  /// Caches the decrypted index as a backup.
  Future<void> cacheIndexBackup(Uint8List decryptedIndex) async {
    _ensureInitialized();
    await _metadataBox!.put('_index_backup', decryptedIndex);
  }

  /// Retrieves the cached index backup.
  Uint8List? getIndexBackup() {
    _ensureInitialized();
    return _metadataBox!.get('_index_backup');
  }

  /// Removes the index backup.
  Future<void> clearIndexBackup() async {
    _ensureInitialized();
    await _metadataBox!.delete('_index_backup');
  }

  // ============ Cleanup ============

  /// Clears all cached data.
  Future<void> clearAll() async {
    _ensureInitialized();
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
