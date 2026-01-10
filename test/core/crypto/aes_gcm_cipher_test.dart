import 'dart:typed_data';

import 'package:aowl/core/crypto/aes_gcm_cipher.dart';
import 'package:aowl/core/crypto/crypto_errors.dart';
import 'package:aowl/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AesGcmCipher cipher;
  late Uint8List validKey;

  setUp(() {
    cipher = AesGcmCipher();
    // Valid 256-bit key
    validKey = Uint8List.fromList(List.generate(32, (i) => i));
  });

  group('AesGcmCipher', () {
    group('encrypt/decrypt roundtrip', () {
      test('successfully encrypts and decrypts plaintext', () {
        final plaintext = Uint8List.fromList('Hello, World!'.codeUnits);

        final encryptResult = cipher.encrypt(plaintext: plaintext, key: validKey);
        expect(encryptResult.isSuccess, isTrue);

        final encrypted = (encryptResult as Success<Uint8List, CryptoError>).value;
        expect(encrypted.length, greaterThan(plaintext.length));

        final decryptResult = cipher.decrypt(encryptedData: encrypted, key: validKey);
        expect(decryptResult.isSuccess, isTrue);

        final decrypted = (decryptResult as Success<Uint8List, CryptoError>).value;
        expect(decrypted, equals(plaintext));
      });

      test('handles empty plaintext', () {
        final plaintext = Uint8List(0);

        final encryptResult = cipher.encrypt(plaintext: plaintext, key: validKey);
        expect(encryptResult.isSuccess, isTrue);

        final encrypted = (encryptResult as Success<Uint8List, CryptoError>).value;

        final decryptResult = cipher.decrypt(encryptedData: encrypted, key: validKey);
        expect(decryptResult.isSuccess, isTrue);

        final decrypted = (decryptResult as Success<Uint8List, CryptoError>).value;
        expect(decrypted, equals(plaintext));
      });

      test('handles large plaintext (1 MB)', () {
        final plaintext = Uint8List.fromList(List.generate(1024 * 1024, (i) => i % 256));

        final encryptResult = cipher.encrypt(plaintext: plaintext, key: validKey);
        expect(encryptResult.isSuccess, isTrue);

        final encrypted = (encryptResult as Success<Uint8List, CryptoError>).value;

        final decryptResult = cipher.decrypt(encryptedData: encrypted, key: validKey);
        expect(decryptResult.isSuccess, isTrue);

        final decrypted = (decryptResult as Success<Uint8List, CryptoError>).value;
        expect(decrypted, equals(plaintext));
      });
    });

    group('unique IVs', () {
      test('generates unique IV for each encryption', () {
        final plaintext = Uint8List.fromList('Test data'.codeUnits);
        final ivSet = <String>{};

        for (var i = 0; i < 100; i++) {
          final result = cipher.encrypt(plaintext: plaintext, key: validKey);
          expect(result.isSuccess, isTrue);

          final encrypted = (result as Success<Uint8List, CryptoError>).value;
          // Extract IV (bytes 4-16)
          final iv = encrypted.sublist(4, 16);
          final ivHex = iv.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

          expect(ivSet.contains(ivHex), isFalse, reason: 'IV should be unique');
          ivSet.add(ivHex);
        }
      });
    });

    group('tamper detection', () {
      test('detects modified ciphertext', () {
        final plaintext = Uint8List.fromList('Sensitive data'.codeUnits);

        final encryptResult = cipher.encrypt(plaintext: plaintext, key: validKey);
        final encrypted = (encryptResult as Success<Uint8List, CryptoError>).value;

        // Tamper with ciphertext (modify byte in the middle)
        final tampered = Uint8List.fromList(encrypted);
        tampered[20] ^= 0xFF;

        final decryptResult = cipher.decrypt(encryptedData: tampered, key: validKey);
        expect(decryptResult.isFailure, isTrue);
        expect((decryptResult as Failure).error, isA<TamperedData>());
      });

      test('detects modified auth tag', () {
        final plaintext = Uint8List.fromList('Sensitive data'.codeUnits);

        final encryptResult = cipher.encrypt(plaintext: plaintext, key: validKey);
        final encrypted = (encryptResult as Success<Uint8List, CryptoError>).value;

        // Tamper with auth tag (last 16 bytes)
        final tampered = Uint8List.fromList(encrypted);
        tampered[tampered.length - 1] ^= 0xFF;

        final decryptResult = cipher.decrypt(encryptedData: tampered, key: validKey);
        expect(decryptResult.isFailure, isTrue);
        expect((decryptResult as Failure).error, isA<TamperedData>());
      });

      test('detects modified IV', () {
        final plaintext = Uint8List.fromList('Sensitive data'.codeUnits);

        final encryptResult = cipher.encrypt(plaintext: plaintext, key: validKey);
        final encrypted = (encryptResult as Success<Uint8List, CryptoError>).value;

        // Tamper with IV (bytes 4-16)
        final tampered = Uint8List.fromList(encrypted);
        tampered[5] ^= 0xFF;

        final decryptResult = cipher.decrypt(encryptedData: tampered, key: validKey);
        expect(decryptResult.isFailure, isTrue);
        expect((decryptResult as Failure).error, isA<TamperedData>());
      });
    });

    group('wrong key rejection', () {
      test('fails to decrypt with wrong key', () {
        final plaintext = Uint8List.fromList('Secret message'.codeUnits);
        final wrongKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));

        final encryptResult = cipher.encrypt(plaintext: plaintext, key: validKey);
        final encrypted = (encryptResult as Success<Uint8List, CryptoError>).value;

        final decryptResult = cipher.decrypt(encryptedData: encrypted, key: wrongKey);
        expect(decryptResult.isFailure, isTrue);
        expect((decryptResult as Failure).error, isA<TamperedData>());
      });
    });

    group('key validation', () {
      test('rejects key shorter than 32 bytes', () {
        final plaintext = Uint8List.fromList('Test'.codeUnits);
        final shortKey = Uint8List(16); // 128-bit key

        final result = cipher.encrypt(plaintext: plaintext, key: shortKey);
        expect(result.isFailure, isTrue);
        expect((result as Failure).error, isA<InvalidKeyLength>());
      });

      test('rejects key longer than 32 bytes', () {
        final plaintext = Uint8List.fromList('Test'.codeUnits);
        final longKey = Uint8List(64); // 512-bit key

        final result = cipher.encrypt(plaintext: plaintext, key: longKey);
        expect(result.isFailure, isTrue);
        expect((result as Failure).error, isA<InvalidKeyLength>());
      });
    });

    group('version handling', () {
      test('extracts version from encrypted data', () {
        final plaintext = Uint8List.fromList('Test'.codeUnits);

        final encryptResult = cipher.encrypt(plaintext: plaintext, key: validKey);
        final encrypted = (encryptResult as Success<Uint8List, CryptoError>).value;

        final versionResult = cipher.extractVersion(encrypted);
        expect(versionResult.isSuccess, isTrue);
        expect((versionResult as Success<int, CryptoError>).value, equals(1));
      });

      test('rejects data with unsupported version', () {
        final plaintext = Uint8List.fromList('Test'.codeUnits);

        final encryptResult = cipher.encrypt(plaintext: plaintext, key: validKey);
        final encrypted = (encryptResult as Success<Uint8List, CryptoError>).value;

        // Modify version to 99
        final modified = Uint8List.fromList(encrypted);
        modified[0] = 99;

        final decryptResult = cipher.decrypt(encryptedData: modified, key: validKey);
        expect(decryptResult.isFailure, isTrue);
        expect((decryptResult as Failure).error, isA<UnsupportedVersion>());
      });
    });

    group('data format validation', () {
      test('rejects data too short', () {
        final shortData = Uint8List(10); // Less than minimum length

        final result = cipher.decrypt(encryptedData: shortData, key: validKey);
        expect(result.isFailure, isTrue);
        expect((result as Failure).error, isA<InvalidDataFormat>());
      });
    });
  });
}
