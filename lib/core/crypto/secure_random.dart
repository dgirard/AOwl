import 'dart:math';
import 'dart:typed_data';

/// Singleton provider for cryptographically secure random bytes.
///
/// Uses Dart's [Random.secure] which delegates to the OS CSPRNG:
/// - Linux: /dev/urandom
/// - macOS: SecRandomCopyBytes
/// - Windows: BCryptGenRandom
/// - Android: /dev/urandom
///
/// SECURITY: Do NOT create new FortunaRandom for each IV generation.
/// This singleton ensures proper seeding from OS entropy source.
class SecureRandomProvider {
  static final SecureRandomProvider _instance = SecureRandomProvider._();

  factory SecureRandomProvider() => _instance;

  SecureRandomProvider._();

  /// Generate [length] cryptographically secure random bytes.
  ///
  /// Uses OS CSPRNG via [Random.secure].
  Uint8List nextBytes(int length) {
    if (length <= 0) {
      throw ArgumentError.value(length, 'length', 'must be positive');
    }
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  /// Generate a random IV for AES-GCM (12 bytes as per NIST recommendation).
  Uint8List generateIv() => nextBytes(12);

  /// Generate a random salt for key derivation (16 bytes).
  Uint8List generateSalt() => nextBytes(16);
}
