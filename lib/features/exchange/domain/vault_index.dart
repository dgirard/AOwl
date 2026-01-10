import 'dart:convert';

import 'vault_entry.dart';

/// The vault index containing all entry metadata.
///
/// Stored encrypted as index.enc in the GitHub vault.
class VaultIndex {
  /// Schema version for forward compatibility.
  final int version;

  /// List of all entries in the vault.
  final List<VaultEntry> entries;

  /// Last modification timestamp.
  final DateTime updatedAt;

  /// Schema version 2 adds retention_period field to entries.
  /// Version 1 entries get null retention (never expires) for backward compatibility.
  static const int currentVersion = 2;

  VaultIndex({
    this.version = currentVersion,
    required this.entries,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  /// Creates an empty index.
  factory VaultIndex.empty() {
    return VaultIndex(entries: []);
  }

  /// Creates from JSON map.
  factory VaultIndex.fromJson(Map<String, dynamic> json) {
    final entriesJson = json['entries'] as List<dynamic>? ?? [];
    return VaultIndex(
      version: json['version'] as int? ?? 1,
      entries: entriesJson
          .map((e) => VaultEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Creates from JSON string.
  factory VaultIndex.fromJsonString(String jsonString) {
    return VaultIndex.fromJson(json.decode(jsonString) as Map<String, dynamic>);
  }

  /// Converts to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'entries': entries.map((e) => e.toJson()).toList(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts to JSON string.
  String toJsonString() => json.encode(toJson());

  /// Gets an entry by ID.
  VaultEntry? getEntry(String id) {
    try {
      return entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if an entry with the given ID exists.
  bool hasEntry(String id) => entries.any((e) => e.id == id);

  /// Adds a new entry and returns updated index.
  VaultIndex addEntry(VaultEntry entry) {
    if (hasEntry(entry.id)) {
      throw ArgumentError('Entry with ID ${entry.id} already exists');
    }
    return VaultIndex(
      version: version,
      entries: [...entries, entry],
    );
  }

  /// Updates an existing entry and returns updated index.
  VaultIndex updateEntry(VaultEntry entry) {
    final index = entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      throw ArgumentError('Entry with ID ${entry.id} not found');
    }
    final newEntries = [...entries];
    newEntries[index] = entry;
    return VaultIndex(
      version: version,
      entries: newEntries,
    );
  }

  /// Removes an entry by ID and returns updated index.
  VaultIndex removeEntry(String id) {
    return VaultIndex(
      version: version,
      entries: entries.where((e) => e.id != id).toList(),
    );
  }

  /// Adds or updates an entry.
  VaultIndex upsertEntry(VaultEntry entry) {
    if (hasEntry(entry.id)) {
      return updateEntry(entry);
    }
    return addEntry(entry);
  }

  /// Returns entries sorted by creation date (newest first).
  List<VaultEntry> get entriesByDate {
    final sorted = [...entries];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// Returns entries of a specific type.
  List<VaultEntry> entriesOfType(EntryType type) {
    return entries.where((e) => e.type == type).toList();
  }

  /// Returns the total number of entries.
  int get count => entries.length;

  /// Returns the total size of all entries.
  int get totalSize => entries.fold(0, (sum, e) => sum + e.sizeBytes);

  /// Returns true if the index is empty.
  bool get isEmpty => entries.isEmpty;

  /// Returns true if the index is not empty.
  bool get isNotEmpty => entries.isNotEmpty;

  /// Merges another index into this one.
  ///
  /// For conflicts (same ID), keeps the entry with the newer updatedAt.
  VaultIndex merge(VaultIndex other) {
    final merged = <String, VaultEntry>{};

    // Add all entries from this index
    for (final entry in entries) {
      merged[entry.id] = entry;
    }

    // Add/update from other index
    for (final entry in other.entries) {
      final existing = merged[entry.id];
      if (existing == null || entry.updatedAt.isAfter(existing.updatedAt)) {
        merged[entry.id] = entry;
      }
    }

    return VaultIndex(
      version: version,
      entries: merged.values.toList(),
    );
  }

  /// Returns all expired entries.
  List<VaultEntry> get expiredEntries {
    return entries.where((e) => e.isExpired).toList();
  }

  /// Removes multiple entries by ID and returns updated index.
  VaultIndex removeEntries(Iterable<String> ids) {
    final idSet = ids.toSet();
    return VaultIndex(
      version: version,
      entries: entries.where((e) => !idSet.contains(e.id)).toList(),
    );
  }

  /// Returns entries that will expire within the given duration.
  List<VaultEntry> entriesExpiringWithin(Duration duration) {
    final threshold = DateTime.now().toUtc().add(duration);
    return entries.where((e) {
      final expiresAt = e.expiresAt;
      return expiresAt != null && expiresAt.isBefore(threshold);
    }).toList();
  }

  @override
  String toString() => 'VaultIndex(v$version, ${entries.length} entries)';
}
