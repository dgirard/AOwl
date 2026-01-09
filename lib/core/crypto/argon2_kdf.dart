import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../utils/result.dart';
import 'crypto_errors.dart';

/// Argon2id Key Derivation Function service.
///
/// Uses OWASP-recommended parameters:
/// - Memory: 48 MB (49152 KB)
/// - Iterations: 3
/// - Parallelism: 2
/// - Hash length: 32 bytes (256 bits)
///
/// Reference: https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
class Argon2KdfService {
  /// Minimum salt length in bytes.
  static const int minSaltLength = 16;

  /// Output key length in bytes (256 bits for AES-256).
  static const int keyLength = 32;

  /// Memory cost in KB (48 MB).
  static const int memoryCostKb = 49152;

  /// Number of iterations.
  static const int iterations = 3;

  /// Degree of parallelism.
  static const int parallelism = 2;

  final Argon2id _argon2id;

  Argon2KdfService()
      : _argon2id = Argon2id(
          memory: memoryCostKb,
          iterations: iterations,
          parallelism: parallelism,
          hashLength: keyLength,
        );

  /// Derives a 256-bit key from password and salt.
  ///
  /// The password should be the concatenation of master password and PIN.
  /// Salt must be at least [minSaltLength] bytes.
  ///
  /// Returns [Success] with derived key or [Failure] with error.
  Future<Result<Uint8List, CryptoError>> deriveKey({
    required String password,
    required Uint8List salt,
  }) async {
    if (salt.length < minSaltLength) {
      return Failure(InvalidSaltLength(
        minLength: minSaltLength,
        actual: salt.length,
      ));
    }

    try {
      final secretKey = await _argon2id.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      final keyBytes = await secretKey.extractBytes();
      return Success(Uint8List.fromList(keyBytes));
    } catch (e) {
      return Failure(KeyDerivationFailed(e.toString()));
    }
  }

  /// Derives a key from password bytes (for binary password data).
  Future<Result<Uint8List, CryptoError>> deriveKeyFromBytes({
    required Uint8List passwordBytes,
    required Uint8List salt,
  }) async {
    if (salt.length < minSaltLength) {
      return Failure(InvalidSaltLength(
        minLength: minSaltLength,
        actual: salt.length,
      ));
    }

    try {
      final secretKey = await _argon2id.deriveKey(
        secretKey: SecretKey(passwordBytes),
        nonce: salt,
      );
      final keyBytes = await secretKey.extractBytes();
      return Success(Uint8List.fromList(keyBytes));
    } catch (e) {
      return Failure(KeyDerivationFailed(e.toString()));
    }
  }
}
