import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../utils/result.dart';
import 'crypto_errors.dart';
import 'secure_random.dart';

/// AES-256-GCM cipher implementation.
///
/// Encrypted format:
/// ```
/// | version (4 bytes) | IV (12 bytes) | ciphertext | auth tag (16 bytes) |
/// ```
///
/// - Version: 32-bit little-endian integer (currently 1)
/// - IV: 12 bytes (96 bits) as per NIST recommendation
/// - Ciphertext: Variable length
/// - Auth tag: 16 bytes (128 bits)
class AesGcmCipher {
  /// Current version of encrypted data format.
  static const int currentVersion = 1;

  /// Key length in bytes (256 bits).
  static const int keyLength = 32;

  /// IV length in bytes (96 bits).
  static const int ivLength = 12;

  /// Auth tag length in bytes (128 bits).
  static const int tagLength = 16;

  /// Version field length in bytes.
  static const int versionLength = 4;

  /// Minimum encrypted data length (version + IV + tag).
  static const int minEncryptedLength = versionLength + ivLength + tagLength;

  final SecureRandomProvider _random;

  AesGcmCipher({SecureRandomProvider? random})
      : _random = random ?? SecureRandomProvider();

  /// Encrypts [plaintext] using AES-256-GCM with the given [key].
  ///
  /// Returns encrypted data in the format:
  /// version (4) + IV (12) + ciphertext + tag (16)
  Result<Uint8List, CryptoError> encrypt({
    required Uint8List plaintext,
    required Uint8List key,
  }) {
    if (key.length != keyLength) {
      return Failure(InvalidKeyLength(expected: keyLength, actual: key.length));
    }

    try {
      final iv = _random.generateIv();
      final cipher = GCMBlockCipher(AESEngine());

      final params = AEADParameters(
        KeyParameter(key),
        tagLength * 8, // Tag length in bits
        iv,
        Uint8List(0), // No additional authenticated data
      );

      cipher.init(true, params); // true for encryption

      // Output buffer: ciphertext + tag
      final ciphertext = Uint8List(plaintext.length + tagLength);
      var offset = cipher.processBytes(
        plaintext,
        0,
        plaintext.length,
        ciphertext,
        0,
      );
      offset += cipher.doFinal(ciphertext, offset);

      // Build output: version + IV + ciphertext + tag
      final output = Uint8List(versionLength + ivLength + offset);
      final byteData = ByteData.view(output.buffer);

      // Write version as little-endian 32-bit integer
      byteData.setInt32(0, currentVersion, Endian.little);

      // Write IV
      output.setRange(versionLength, versionLength + ivLength, iv);

      // Write ciphertext + tag
      output.setRange(versionLength + ivLength, output.length, ciphertext);

      return Success(output);
    } catch (e) {
      return Failure(DecryptionFailed('Encryption failed: $e'));
    }
  }

  /// Decrypts [encryptedData] using AES-256-GCM with the given [key].
  ///
  /// Expects data in the format:
  /// version (4) + IV (12) + ciphertext + tag (16)
  Result<Uint8List, CryptoError> decrypt({
    required Uint8List encryptedData,
    required Uint8List key,
  }) {
    if (key.length != keyLength) {
      return Failure(InvalidKeyLength(expected: keyLength, actual: key.length));
    }

    if (encryptedData.length < minEncryptedLength) {
      return Failure(InvalidDataFormat(
        'Data too short: ${encryptedData.length} bytes, minimum: $minEncryptedLength',
      ));
    }

    try {
      final byteData = ByteData.view(encryptedData.buffer);

      // Read version
      final version = byteData.getInt32(0, Endian.little);
      if (version != currentVersion) {
        return Failure(UnsupportedVersion(version: version));
      }

      // Extract IV
      final iv = encryptedData.sublist(versionLength, versionLength + ivLength);

      // Extract ciphertext + tag
      final ciphertextWithTag = encryptedData.sublist(versionLength + ivLength);

      final cipher = GCMBlockCipher(AESEngine());

      final params = AEADParameters(
        KeyParameter(key),
        tagLength * 8, // Tag length in bits
        iv,
        Uint8List(0), // No additional authenticated data
      );

      cipher.init(false, params); // false for decryption

      // Output buffer: plaintext (ciphertext length - tag)
      final plaintext = Uint8List(ciphertextWithTag.length - tagLength);
      var offset = cipher.processBytes(
        ciphertextWithTag,
        0,
        ciphertextWithTag.length,
        plaintext,
        0,
      );

      try {
        cipher.doFinal(plaintext, offset);
      } on InvalidCipherTextException {
        return const Failure(TamperedData());
      }

      return Success(plaintext);
    } on InvalidCipherTextException {
      return const Failure(TamperedData());
    } catch (e) {
      return Failure(DecryptionFailed('Decryption failed: $e'));
    }
  }

  /// Extracts the version number from encrypted data without decrypting.
  Result<int, CryptoError> extractVersion(Uint8List encryptedData) {
    if (encryptedData.length < versionLength) {
      return Failure(InvalidDataFormat(
        'Data too short to contain version: ${encryptedData.length} bytes',
      ));
    }

    final byteData = ByteData.view(encryptedData.buffer);
    return Success(byteData.getInt32(0, Endian.little));
  }
}
