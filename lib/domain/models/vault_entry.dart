import 'package:uuid/uuid.dart';

/// Retention periods for auto-deletion.
/// Controls how long a document is kept before automatic cleanup.
enum RetentionPeriod {
  oneMinute('1m', Duration(minutes: 1), '1 minute'),
  oneHour('1h', Duration(hours: 1), '1 hour'),
  oneDay('1d', Duration(days: 1), '1 day'),
  oneWeek('1w', Duration(days: 7), '1 week'),
  oneMonth('1M', Duration(days: 30), '1 month'),
  oneYear('1y', Duration(days: 365), '1 year'),
  tenYears('10y', Duration(days: 3650), '10 years'),
  hundredYears('100y', Duration(days: 36500), 'Forever');

  const RetentionPeriod(this.code, this.duration, this.label);

  /// Short code for serialization (e.g., "1d", "1w").
  final String code;

  /// Duration of the retention period.
  final Duration duration;

  /// Human-readable label.
  final String label;

  /// Calculates the expiration date from a given start time.
  DateTime calculateExpiration(DateTime from) => from.add(duration);

  /// Parses a retention period from its code.
  static RetentionPeriod fromCode(String code) {
    return RetentionPeriod.values.firstWhere(
      (p) => p.code == code,
      orElse: () => RetentionPeriod.oneDay,
    );
  }

  /// Default retention period for new entries.
  static RetentionPeriod get defaultPeriod => RetentionPeriod.oneDay;
}

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

  /// Retention period for auto-deletion.
  /// null = never expires (backward compatibility for existing entries).
  final RetentionPeriod? retentionPeriod;

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
    this.retentionPeriod,
  });

  /// Creates a new entry with a generated UUID.
  factory VaultEntry.create({
    required EntryType type,
    required String label,
    String? mimeType,
    required int sizeBytes,
    RetentionPeriod? retentionPeriod,
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
      retentionPeriod: retentionPeriod ?? RetentionPeriod.defaultPeriod,
    );
  }

  /// Creates from JSON map.
  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    final retentionCode = json['retention_period'] as String?;
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
      retentionPeriod:
          retentionCode != null ? RetentionPeriod.fromCode(retentionCode) : null,
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
      if (retentionPeriod != null) 'retention_period': retentionPeriod!.code,
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
    RetentionPeriod? retentionPeriod,
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
      retentionPeriod: retentionPeriod ?? this.retentionPeriod,
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

  /// Calculated expiration timestamp (UTC).
  /// Returns null if no retention period is set (never expires).
  DateTime? get expiresAt {
    return retentionPeriod?.calculateExpiration(createdAt);
  }

  /// Check if entry has expired (using UTC for timezone safety).
  bool get isExpired {
    final exp = expiresAt;
    return exp != null && DateTime.now().toUtc().isAfter(exp);
  }

  /// Time remaining before expiration.
  /// Returns null if no retention period is set.
  Duration? get timeRemaining {
    final exp = expiresAt;
    if (exp == null) return null;
    final remaining = exp.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Formats the remaining time as a human-readable string.
  String? get formattedTimeRemaining {
    final remaining = timeRemaining;
    if (remaining == null) return null;
    if (remaining == Duration.zero) return 'Expired';

    if (remaining.inDays > 365) {
      final years = remaining.inDays ~/ 365;
      return '$years ${years == 1 ? 'year' : 'years'}';
    }
    if (remaining.inDays > 30) {
      final months = remaining.inDays ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'}';
    }
    if (remaining.inDays > 0) {
      return '${remaining.inDays} ${remaining.inDays == 1 ? 'day' : 'days'}';
    }
    if (remaining.inHours > 0) {
      return '${remaining.inHours} ${remaining.inHours == 1 ? 'hour' : 'hours'}';
    }
    if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes} ${remaining.inMinutes == 1 ? 'min' : 'mins'}';
    }
    return '< 1 min';
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
