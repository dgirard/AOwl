import 'package:uuid/uuid.dart';

/// Type of vault entry.
enum EntryType {
  text,
  image;

  String toJson() => name;

  static EntryType fromJson(String json) {
    return EntryType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => EntryType.text,
    );
  }
}

/// Represents a single entry in the encrypted vault.
class VaultEntry {
  /// Unique identifier (UUID v4).
  final String id;

  /// Filename in the vault (e.g., "{id}.enc").
  final String filename;

  /// Type of content.
  final EntryType type;

  /// User-provided label/description.
  final String label;

  /// MIME type of the original content.
  final String? mimeType;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;

  /// Size of encrypted content in bytes.
  final int sizeBytes;

  /// GitHub SHA for version tracking.
  final String? sha;

  VaultEntry({
    required this.id,
    required this.filename,
    required this.type,
    required this.label,
    this.mimeType,
    required this.createdAt,
    required this.updatedAt,
    required this.sizeBytes,
    this.sha,
  });

  /// Creates a new entry with a generated UUID.
  factory VaultEntry.create({
    required EntryType type,
    required String label,
    String? mimeType,
    required int sizeBytes,
  }) {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc();
    return VaultEntry(
      id: id,
      filename: '$id.enc',
      type: type,
      label: label,
      mimeType: mimeType,
      createdAt: now,
      updatedAt: now,
      sizeBytes: sizeBytes,
    );
  }

  /// Creates from JSON map.
  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    return VaultEntry(
      id: json['id'] as String,
      filename: json['filename'] as String,
      type: EntryType.fromJson(json['type'] as String),
      label: json['label'] as String,
      mimeType: json['mime_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sizeBytes: json['size_bytes'] as int,
      sha: json['sha'] as String?,
    );
  }

  /// Converts to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'type': type.toJson(),
      'label': label,
      if (mimeType != null) 'mime_type': mimeType,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'size_bytes': sizeBytes,
      if (sha != null) 'sha': sha,
    };
  }

  /// Creates a copy with updated fields.
  VaultEntry copyWith({
    String? id,
    String? filename,
    EntryType? type,
    String? label,
    String? mimeType,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sizeBytes,
    String? sha,
  }) {
    return VaultEntry(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      type: type ?? this.type,
      label: label ?? this.label,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      sha: sha ?? this.sha,
    );
  }

  /// Updates the SHA and updatedAt timestamp.
  VaultEntry withSha(String newSha) {
    return copyWith(
      sha: newSha,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// Returns true if this is a text entry.
  bool get isText => type == EntryType.text;

  /// Returns true if this is an image entry.
  bool get isImage => type == EntryType.image;

  /// Returns a human-readable size string.
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VaultEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VaultEntry($id, $label, $type)';
}
