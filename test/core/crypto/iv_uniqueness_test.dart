import 'dart:typed_data';

import 'package:ashare/core/crypto/aes_gcm_cipher.dart';
import 'package:ashare/core/crypto/crypto_errors.dart';
import 'package:ashare/core/crypto/secure_random.dart';
import 'package:ashare/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IV Uniqueness Tests', () {
    // SECURITY: Reusing an IV with the same key completely breaks AES-GCM.
    // These tests verify that IVs are never reused.

    test('SecureRandomProvider generates unique IVs over 10,000 encryptions', () {
      final random = SecureRandomProvider();
      final ivSet = <String>{};

      for (var i = 0; i < 10000; i++) {
        final iv = random.generateIv();
        final ivHex = iv.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

        expect(
          ivSet.contains(ivHex),
          isFalse,
          reason: 'IV collision detected at iteration $i',
        );
        ivSet.add(ivHex);
      }

      expect(ivSet.length, equals(10000));
    });

    test('AesGcmCipher generates unique IVs in encrypted output', () {
      final cipher = AesGcmCipher();
      final key = Uint8List.fromList(List.filled(32, 0x00));
      final plaintext = Uint8List.fromList([1, 2, 3]);
      final ivSet = <String>{};

      for (var i = 0; i < 10000; i++) {
        final result = cipher.encrypt(plaintext: plaintext, key: key);
        expect(result.isSuccess, isTrue);

        final encrypted = (result as Success<Uint8List, CryptoError>).value;

        // Extract IV from encrypted data (bytes 4-16)
        final iv = encrypted.sublist(4, 16);
        final ivHex = iv.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

        expect(
          ivSet.contains(ivHex),
          isFalse,
          reason: 'IV collision detected at iteration $i',
        );
        ivSet.add(ivHex);
      }

      expect(ivSet.length, equals(10000));
    });

    test('parallel encryption does not produce duplicate IVs', () async {
      final cipher = AesGcmCipher();
      final key = Uint8List.fromList(List.filled(32, 0x00));
      final plaintext = Uint8List.fromList([1, 2, 3]);

      // Simulate parallel encryption by running multiple encryptions
      final futures = <Future<Result<Uint8List, CryptoError>>>[];
      for (var i = 0; i < 1000; i++) {
        futures.add(Future(() => cipher.encrypt(plaintext: plaintext, key: key)));
      }

      final results = await Future.wait(futures);
      final ivSet = <String>{};

      for (var i = 0; i < results.length; i++) {
        final result = results[i];
        expect(result.isSuccess, isTrue);

        final encrypted = (result as Success<Uint8List, CryptoError>).value;
        final iv = encrypted.sublist(4, 16);
        final ivHex = iv.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

        expect(
          ivSet.contains(ivHex),
          isFalse,
          reason: 'IV collision detected at index $i',
        );
        ivSet.add(ivHex);
      }

      expect(ivSet.length, equals(1000));
    });

    test('IV entropy distribution is uniform', () {
      // This test verifies that IV bytes are uniformly distributed,
      // which is a necessary (but not sufficient) condition for randomness.

      final random = SecureRandomProvider();
      final byteCounts = List.filled(256, 0);
      const samples = 100000;
      const bytesPerSample = 12;

      for (var i = 0; i < samples; i++) {
        final iv = random.generateIv();
        for (var b in iv) {
          byteCounts[b]++;
        }
      }

      // Expected count per byte value
      final expectedCount = (samples * bytesPerSample) / 256;

      // Allow 20% deviation from expected (chi-squared would be more rigorous)
      final minCount = (expectedCount * 0.8).round();
      final maxCount = (expectedCount * 1.2).round();

      var outliers = 0;
      for (var i = 0; i < 256; i++) {
        if (byteCounts[i] < minCount || byteCounts[i] > maxCount) {
          outliers++;
        }
      }

      // Allow up to 5% of values to be outliers (due to random variation)
      expect(
        outliers,
        lessThan(13), // 5% of 256
        reason: 'Too many byte values outside expected range: $outliers',
      );
    });

    test('consecutive IVs are not sequential', () {
      // Verify that IVs don't follow a predictable pattern
      final random = SecureRandomProvider();

      var sequentialCount = 0;
      Uint8List? previousIv;

      for (var i = 0; i < 1000; i++) {
        final iv = random.generateIv();

        if (previousIv != null) {
          // Check if this IV is exactly previous + 1 (very unlikely for random)
          var isSequential = true;
          for (var j = 11; j >= 0; j--) {
            if (previousIv[j] != 255) {
              if (iv[j] != previousIv[j] + 1) {
                isSequential = false;
              }
              break;
            }
          }
          if (isSequential) sequentialCount++;
        }

        previousIv = iv;
      }

      // Should be essentially zero sequential IVs with proper randomness
      // Allow up to 10 for edge cases in statistical testing
      expect(sequentialCount, lessThanOrEqualTo(10));
    });
  });
}
