import 'dart:convert';
import 'dart:typed_data';

/// Configuration stored on GitHub for multi-device sync.
///
/// Contains the salt needed to derive the same master key on all devices.
/// The salt is stored in plaintext as it doesn't need to be secret.
class VaultConfig {
  /// Current config version.
  static const int currentVersion = 1;

  /// Config version for future migrations.
  final int version;

  /// Salt for key derivation (base64 encoded in JSON).
  final Uint8List salt;

  /// When the vault was first created.
  final DateTime createdAt;

  VaultConfig({
    required this.version,
    required this.salt,
    required this.createdAt,
  });

  /// Creates a new config with a generated salt.
  factory VaultConfig.create({required Uint8List salt}) {
    return VaultConfig(
      version: currentVersion,
      salt: salt,
      createdAt: DateTime.now(),
    );
  }

  /// Parses config from JSON string.
  factory VaultConfig.fromJsonString(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return VaultConfig(
      version: map['version'] as int,
      salt: base64Decode(map['salt'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Converts config to JSON string.
  String toJsonString() {
    return jsonEncode({
      'version': version,
      'salt': base64Encode(salt),
      'createdAt': createdAt.toIso8601String(),
    });
  }
}
