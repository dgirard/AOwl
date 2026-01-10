import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/crypto_service.dart';
import '../../core/storage/local_cache_service.dart';
import '../../core/storage/secure_storage_service.dart';

/// Provider for the secure storage service.
///
/// Used across the application for storing sensitive data like
/// master key, PIN hash, GitHub token, etc.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider for the crypto service.
///
/// Provides AES-256-GCM encryption/decryption and Argon2id key derivation.
final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return CryptoService();
});

/// Provider for the local cache service.
///
/// Used for caching encrypted files and index backups locally.
final localCacheProvider = Provider<LocalCacheService>((ref) {
  return LocalCacheService();
});
