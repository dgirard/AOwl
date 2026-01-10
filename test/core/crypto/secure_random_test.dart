import 'dart:typed_data';

import 'package:aowl/core/crypto/secure_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecureRandomProvider', () {
    late SecureRandomProvider random;

    setUp(() {
      random = SecureRandomProvider();
    });

    group('singleton', () {
      test('returns same instance', () {
        final instance1 = SecureRandomProvider();
        final instance2 = SecureRandomProvider();
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('nextBytes', () {
      test('returns requested number of bytes', () {
        final bytes = random.nextBytes(16);
        expect(bytes.length, equals(16));
      });

      test('returns Uint8List', () {
        final bytes = random.nextBytes(8);
        expect(bytes, isA<Uint8List>());
      });

      test('throws for zero length', () {
        expect(() => random.nextBytes(0), throwsArgumentError);
      });

      test('throws for negative length', () {
        expect(() => random.nextBytes(-1), throwsArgumentError);
      });

      test('generates different values on each call', () {
        final bytes1 = random.nextBytes(32);
        final bytes2 = random.nextBytes(32);
        expect(bytes1, isNot(equals(bytes2)));
      });

      test('handles large requests', () {
        final bytes = random.nextBytes(1024 * 1024); // 1 MB
        expect(bytes.length, equals(1024 * 1024));
      });
    });

    group('generateIv', () {
      test('returns 12 bytes', () {
        final iv = random.generateIv();
        expect(iv.length, equals(12));
      });

      test('generates unique IVs', () {
        final ivs = <String>{};
        for (var i = 0; i < 1000; i++) {
          final iv = random.generateIv();
          final hex = iv.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          expect(ivs.contains(hex), isFalse);
          ivs.add(hex);
        }
      });
    });

    group('generateSalt', () {
      test('returns 16 bytes', () {
        final salt = random.generateSalt();
        expect(salt.length, equals(16));
      });

      test('generates unique salts', () {
        final salts = <String>{};
        for (var i = 0; i < 1000; i++) {
          final salt = random.generateSalt();
          final hex = salt.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          expect(salts.contains(hex), isFalse);
          salts.add(hex);
        }
      });
    });
  });
}
