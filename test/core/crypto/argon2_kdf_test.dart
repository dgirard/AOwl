import 'dart:typed_data';

import 'package:ashare/core/crypto/argon2_kdf.dart';
import 'package:ashare/core/crypto/crypto_errors.dart';
import 'package:ashare/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Argon2KdfService kdf;
  late Uint8List validSalt;

  setUp(() {
    kdf = Argon2KdfService();
    validSalt = Uint8List.fromList(List.generate(16, (i) => i));
  });

  group('Argon2KdfService', () {
    group('deriveKey', () {
      test('derives 32-byte key from password and salt', () async {
        final result = await kdf.deriveKey(
          password: 'test-password',
          salt: validSalt,
        );

        expect(result.isSuccess, isTrue);
        final key = (result as Success<Uint8List, CryptoError>).value;
        expect(key.length, equals(32));
      });

      test('produces deterministic output for same input', () async {
        final result1 = await kdf.deriveKey(
          password: 'same-password',
          salt: validSalt,
        );
        final result2 = await kdf.deriveKey(
          password: 'same-password',
          salt: validSalt,
        );

        expect(result1.isSuccess, isTrue);
        expect(result2.isSuccess, isTrue);

        final key1 = (result1 as Success<Uint8List, CryptoError>).value;
        final key2 = (result2 as Success<Uint8List, CryptoError>).value;
        expect(key1, equals(key2));
      });

      test('produces different output for different passwords', () async {
        final result1 = await kdf.deriveKey(
          password: 'password1',
          salt: validSalt,
        );
        final result2 = await kdf.deriveKey(
          password: 'password2',
          salt: validSalt,
        );

        expect(result1.isSuccess, isTrue);
        expect(result2.isSuccess, isTrue);

        final key1 = (result1 as Success<Uint8List, CryptoError>).value;
        final key2 = (result2 as Success<Uint8List, CryptoError>).value;
        expect(key1, isNot(equals(key2)));
      });

      test('produces different output for different salts', () async {
        final salt2 = Uint8List.fromList(List.generate(16, (i) => 255 - i));

        final result1 = await kdf.deriveKey(
          password: 'same-password',
          salt: validSalt,
        );
        final result2 = await kdf.deriveKey(
          password: 'same-password',
          salt: salt2,
        );

        expect(result1.isSuccess, isTrue);
        expect(result2.isSuccess, isTrue);

        final key1 = (result1 as Success<Uint8List, CryptoError>).value;
        final key2 = (result2 as Success<Uint8List, CryptoError>).value;
        expect(key1, isNot(equals(key2)));
      });
    });

    group('salt validation', () {
      test('rejects salt shorter than 16 bytes', () async {
        final shortSalt = Uint8List(8);

        final result = await kdf.deriveKey(
          password: 'test',
          salt: shortSalt,
        );

        expect(result.isFailure, isTrue);
        expect((result as Failure).error, isA<InvalidSaltLength>());
      });

      test('accepts salt exactly 16 bytes', () async {
        final salt = Uint8List(16);

        final result = await kdf.deriveKey(
          password: 'test',
          salt: salt,
        );

        expect(result.isSuccess, isTrue);
      });

      test('accepts salt longer than 16 bytes', () async {
        final longSalt = Uint8List(32);

        final result = await kdf.deriveKey(
          password: 'test',
          salt: longSalt,
        );

        expect(result.isSuccess, isTrue);
      });
    });

    group('deriveKeyFromBytes', () {
      test('derives key from binary password data', () async {
        final passwordBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        final result = await kdf.deriveKeyFromBytes(
          passwordBytes: passwordBytes,
          salt: validSalt,
        );

        expect(result.isSuccess, isTrue);
        final key = (result as Success<Uint8List, CryptoError>).value;
        expect(key.length, equals(32));
      });
    });

    group('configuration', () {
      test('has correct memory cost', () {
        expect(Argon2KdfService.memoryCostKb, equals(49152)); // 48 MB
      });

      test('has correct iterations', () {
        expect(Argon2KdfService.iterations, equals(3));
      });

      test('has correct parallelism', () {
        expect(Argon2KdfService.parallelism, equals(2));
      });

      test('has correct key length', () {
        expect(Argon2KdfService.keyLength, equals(32)); // 256 bits
      });
    });
  });
}
