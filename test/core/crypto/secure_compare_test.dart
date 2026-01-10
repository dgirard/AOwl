import 'dart:typed_data';

import 'package:aowl/core/crypto/secure_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('constantTimeEquals', () {
    test('returns true for equal byte arrays', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4, 5];
      expect(constantTimeEquals(a, b), isTrue);
    });

    test('returns false for different byte arrays', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4, 6];
      expect(constantTimeEquals(a, b), isFalse);
    });

    test('returns false for different lengths', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4];
      expect(constantTimeEquals(a, b), isFalse);
    });

    test('returns true for empty arrays', () {
      final a = <int>[];
      final b = <int>[];
      expect(constantTimeEquals(a, b), isTrue);
    });

    test('handles single byte arrays', () {
      expect(constantTimeEquals([0], [0]), isTrue);
      expect(constantTimeEquals([0], [1]), isFalse);
    });

    test('handles all-zero arrays', () {
      final a = List.filled(32, 0);
      final b = List.filled(32, 0);
      expect(constantTimeEquals(a, b), isTrue);
    });

    test('handles all-ones arrays', () {
      final a = List.filled(32, 255);
      final b = List.filled(32, 255);
      expect(constantTimeEquals(a, b), isTrue);
    });
  });

  group('constantTimeEqualsUint8List', () {
    test('returns true for equal Uint8List', () {
      final a = Uint8List.fromList([1, 2, 3, 4, 5]);
      final b = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(constantTimeEqualsUint8List(a, b), isTrue);
    });

    test('returns false for different Uint8List', () {
      final a = Uint8List.fromList([1, 2, 3, 4, 5]);
      final b = Uint8List.fromList([1, 2, 3, 4, 6]);
      expect(constantTimeEqualsUint8List(a, b), isFalse);
    });
  });

  group('constantTimeEqualsHex', () {
    test('returns true for equal hex strings', () {
      expect(constantTimeEqualsHex('deadbeef', 'deadbeef'), isTrue);
    });

    test('returns false for different hex strings', () {
      expect(constantTimeEqualsHex('deadbeef', 'deadbeee'), isFalse);
    });

    test('returns false for different lengths', () {
      expect(constantTimeEqualsHex('deadbeef', 'dead'), isFalse);
    });

    test('returns false for odd-length strings', () {
      expect(constantTimeEqualsHex('abc', 'abc'), isFalse);
    });

    test('returns true for empty strings', () {
      expect(constantTimeEqualsHex('', ''), isTrue);
    });

    test('handles case in hex strings', () {
      // Dart's int.parse is case-insensitive for hex
      // So 'DEADBEEF' and 'deadbeef' parse to the same bytes
      expect(constantTimeEqualsHex('DEADBEEF', 'deadbeef'), isTrue);
      expect(constantTimeEqualsHex('DeAdBeEf', 'deadbeef'), isTrue);
    });

    test('returns false for invalid hex', () {
      expect(constantTimeEqualsHex('ghij', 'ghij'), isFalse);
    });
  });
}
