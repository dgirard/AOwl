import 'dart:typed_data';

/// Performs constant-time comparison of two byte sequences.
///
/// SECURITY: Standard `==` comparison is vulnerable to timing attacks
/// because it returns early on first mismatch. This implementation
/// always compares all bytes regardless of where differences occur.
///
/// Returns `true` if [a] and [b] are equal, `false` otherwise.
bool constantTimeEquals(List<int> a, List<int> b) {
  // Length comparison leaks length info but that's acceptable
  // for our use case (fixed-length hashes)
  if (a.length != b.length) return false;

  var result = 0;
  for (var i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result == 0;
}

/// Constant-time comparison for [Uint8List].
bool constantTimeEqualsUint8List(Uint8List a, Uint8List b) {
  return constantTimeEquals(a, b);
}

/// Constant-time comparison for hex-encoded strings.
///
/// Converts both strings to bytes and compares them.
/// Returns `false` if strings have different lengths or invalid hex.
bool constantTimeEqualsHex(String a, String b) {
  if (a.length != b.length) return false;
  if (a.length % 2 != 0) return false;

  try {
    final bytesA = _hexToBytes(a);
    final bytesB = _hexToBytes(b);
    return constantTimeEquals(bytesA, bytesB);
  } catch (_) {
    return false;
  }
}

Uint8List _hexToBytes(String hex) {
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}
