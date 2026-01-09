/// Sealed hierarchy of crypto-related errors.
///
/// Using sealed classes ensures exhaustive handling in switch statements.
sealed class CryptoError {
  const CryptoError();

  /// Human-readable error message.
  String get message;
}

/// Decryption failed due to invalid ciphertext or wrong key.
final class DecryptionFailed extends CryptoError {
  final String? details;

  const DecryptionFailed([this.details]);

  @override
  String get message => details ?? 'Decryption failed';

  @override
  String toString() => 'DecryptionFailed($message)';
}

/// Key length is invalid for the algorithm.
final class InvalidKeyLength extends CryptoError {
  final int expected;
  final int actual;

  const InvalidKeyLength({required this.expected, required this.actual});

  @override
  String get message => 'Invalid key length: expected $expected, got $actual';

  @override
  String toString() => 'InvalidKeyLength($message)';
}

/// Authentication tag verification failed - data may have been tampered.
final class TamperedData extends CryptoError {
  const TamperedData();

  @override
  String get message => 'Data integrity check failed - possible tampering';

  @override
  String toString() => 'TamperedData($message)';
}

/// Encrypted data version is not supported.
final class UnsupportedVersion extends CryptoError {
  final int version;
  final List<int> supportedVersions;

  const UnsupportedVersion({
    required this.version,
    this.supportedVersions = const [1],
  });

  @override
  String get message =>
      'Unsupported version: $version (supported: $supportedVersions)';

  @override
  String toString() => 'UnsupportedVersion($message)';
}

/// IV/nonce length is invalid.
final class InvalidIvLength extends CryptoError {
  final int expected;
  final int actual;

  const InvalidIvLength({required this.expected, required this.actual});

  @override
  String get message => 'Invalid IV length: expected $expected, got $actual';

  @override
  String toString() => 'InvalidIvLength($message)';
}

/// Salt length is invalid for key derivation.
final class InvalidSaltLength extends CryptoError {
  final int minLength;
  final int actual;

  const InvalidSaltLength({required this.minLength, required this.actual});

  @override
  String get message =>
      'Invalid salt length: minimum $minLength, got $actual';

  @override
  String toString() => 'InvalidSaltLength($message)';
}

/// Key derivation failed.
final class KeyDerivationFailed extends CryptoError {
  final String? details;

  const KeyDerivationFailed([this.details]);

  @override
  String get message => details ?? 'Key derivation failed';

  @override
  String toString() => 'KeyDerivationFailed($message)';
}

/// Encrypted data format is invalid.
final class InvalidDataFormat extends CryptoError {
  final String? details;

  const InvalidDataFormat([this.details]);

  @override
  String get message => details ?? 'Invalid encrypted data format';

  @override
  String toString() => 'InvalidDataFormat($message)';
}
