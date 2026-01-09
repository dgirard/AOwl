import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import '../utils/result.dart';
import 'aes_gcm_cipher.dart';
import 'argon2_kdf.dart';
import 'crypto_errors.dart';
import 'secure_compare.dart';
import 'secure_random.dart';

/// High-level crypto service facade combining KDF, cipher, and utilities.
///
/// Provides the main API for:
/// - Key derivation from password + PIN
/// - Encrypting/decrypting vault entries
/// - PIN hash generation and verification
/// - Salt and IV generation
class CryptoService {
  final Argon2KdfService _kdf;
  final AesGcmCipher _cipher;
  final SecureRandomProvider _random;

  CryptoService({
    Argon2KdfService? kdf,
    AesGcmCipher? cipher,
    SecureRandomProvider? random,
  })  : _kdf = kdf ?? Argon2KdfService(),
        _cipher = cipher ?? AesGcmCipher(),
        _random = random ?? SecureRandomProvider();

  /// Generates a cryptographically secure random salt.
  Uint8List generateSalt() => _random.generateSalt();

  /// Derives a master key from password, PIN, and salt.
  ///
  /// The password and PIN are concatenated before derivation.
  Future<Result<Uint8List, CryptoError>> deriveKey({
    required String password,
    required String pin,
    required Uint8List salt,
  }) async {
    final combined = '$password$pin';
    return _kdf.deriveKey(password: combined, salt: salt);
  }

  /// Encrypts plaintext bytes with the given key.
  Result<Uint8List, CryptoError> encrypt({
    required Uint8List plaintext,
    required Uint8List key,
  }) {
    return _cipher.encrypt(plaintext: plaintext, key: key);
  }

  /// Decrypts encrypted bytes with the given key.
  Result<Uint8List, CryptoError> decrypt({
    required Uint8List encryptedData,
    required Uint8List key,
  }) {
    return _cipher.decrypt(encryptedData: encryptedData, key: key);
  }

  /// Encrypts a string (UTF-8 encoded) with the given key.
  Result<Uint8List, CryptoError> encryptString({
    required String plaintext,
    required Uint8List key,
  }) {
    final bytes = Uint8List.fromList(utf8.encode(plaintext));
    return encrypt(plaintext: bytes, key: key);
  }

  /// Decrypts encrypted data and returns as UTF-8 string.
  Result<String, CryptoError> decryptString({
    required Uint8List encryptedData,
    required Uint8List key,
  }) {
    return decrypt(encryptedData: encryptedData, key: key).map(
      (bytes) => utf8.decode(bytes),
    );
  }

  /// Generates a SHA-256 hash of the PIN for quick unlock verification.
  ///
  /// SECURITY: Use [verifyPinHash] for verification, which uses
  /// constant-time comparison to prevent timing attacks.
  Uint8List hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = crypto.sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }

  /// Verifies a PIN against its hash using constant-time comparison.
  ///
  /// SECURITY: This method is safe against timing attacks.
  bool verifyPinHash(String pin, Uint8List storedHash) {
    final computedHash = hashPin(pin);
    return constantTimeEqualsUint8List(computedHash, storedHash);
  }

  /// Extracts the version from encrypted data without decrypting.
  Result<int, CryptoError> extractVersion(Uint8List encryptedData) {
    return _cipher.extractVersion(encryptedData);
  }
}
