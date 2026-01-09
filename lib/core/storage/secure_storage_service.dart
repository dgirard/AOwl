import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for secure storage items.
abstract class SecureStorageKeys {
  static const String masterKey = 'master_key';
  static const String salt = 'salt';
  static const String pinHash = 'pin_hash';
  static const String githubToken = 'github_token';
  static const String repoOwner = 'repo_owner';
  static const String repoName = 'repo_name';
  static const String failedAttempts = 'failed_attempts';
  static const String lockoutUntil = 'lockout_until';
  static const String indexSha = 'index_sha';
  static const String configSha = 'config_sha';
  static const String lastSyncAt = 'last_sync_at';
}

/// Service for storing sensitive data in platform secure storage.
///
/// Uses:
/// - macOS: Keychain
/// - Android: EncryptedSharedPreferences / Keystore
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
              mOptions: MacOsOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  // ============ Master Key ============

  /// Stores the derived master key (base64 encoded).
  Future<void> setMasterKey(Uint8List key) async {
    await _storage.write(
      key: SecureStorageKeys.masterKey,
      value: base64.encode(key),
    );
  }

  /// Retrieves the stored master key.
  Future<Uint8List?> getMasterKey() async {
    final value = await _storage.read(key: SecureStorageKeys.masterKey);
    if (value == null) return null;
    return base64.decode(value);
  }

  /// Clears the master key (for logout/lock).
  Future<void> clearMasterKey() async {
    await _storage.delete(key: SecureStorageKeys.masterKey);
  }

  // ============ Salt ============

  /// Stores the KDF salt (base64 encoded).
  Future<void> setSalt(Uint8List salt) async {
    await _storage.write(
      key: SecureStorageKeys.salt,
      value: base64.encode(salt),
    );
  }

  /// Retrieves the stored salt.
  Future<Uint8List?> getSalt() async {
    final value = await _storage.read(key: SecureStorageKeys.salt);
    if (value == null) return null;
    return base64.decode(value);
  }

  // ============ PIN Hash ============

  /// Stores the SHA-256 hash of the PIN (base64 encoded).
  Future<void> setPinHash(Uint8List hash) async {
    await _storage.write(
      key: SecureStorageKeys.pinHash,
      value: base64.encode(hash),
    );
  }

  /// Retrieves the stored PIN hash.
  Future<Uint8List?> getPinHash() async {
    final value = await _storage.read(key: SecureStorageKeys.pinHash);
    if (value == null) return null;
    return base64.decode(value);
  }

  // ============ GitHub Credentials ============

  /// Stores the GitHub Personal Access Token.
  Future<void> setGitHubToken(String token) async {
    await _storage.write(key: SecureStorageKeys.githubToken, value: token);
  }

  /// Retrieves the stored GitHub token.
  Future<String?> getGitHubToken() async {
    return _storage.read(key: SecureStorageKeys.githubToken);
  }

  /// Stores the repository owner.
  Future<void> setRepoOwner(String owner) async {
    await _storage.write(key: SecureStorageKeys.repoOwner, value: owner);
  }

  /// Retrieves the repository owner.
  Future<String?> getRepoOwner() async {
    return _storage.read(key: SecureStorageKeys.repoOwner);
  }

  /// Stores the repository name.
  Future<void> setRepoName(String name) async {
    await _storage.write(key: SecureStorageKeys.repoName, value: name);
  }

  /// Retrieves the repository name.
  Future<String?> getRepoName() async {
    return _storage.read(key: SecureStorageKeys.repoName);
  }

  // ============ Rate Limiting ============

  /// Stores the count of failed PIN attempts.
  Future<void> setFailedAttempts(int count) async {
    await _storage.write(
      key: SecureStorageKeys.failedAttempts,
      value: count.toString(),
    );
  }

  /// Retrieves the failed attempts count.
  Future<int> getFailedAttempts() async {
    final value = await _storage.read(key: SecureStorageKeys.failedAttempts);
    return int.tryParse(value ?? '0') ?? 0;
  }

  /// Clears the failed attempts counter.
  Future<void> clearFailedAttempts() async {
    await _storage.delete(key: SecureStorageKeys.failedAttempts);
  }

  /// Stores the lockout expiration time.
  Future<void> setLockoutUntil(DateTime until) async {
    await _storage.write(
      key: SecureStorageKeys.lockoutUntil,
      value: until.toIso8601String(),
    );
  }

  /// Retrieves the lockout expiration time.
  Future<DateTime?> getLockoutUntil() async {
    final value = await _storage.read(key: SecureStorageKeys.lockoutUntil);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Clears the lockout.
  Future<void> clearLockout() async {
    await _storage.delete(key: SecureStorageKeys.lockoutUntil);
  }

  // ============ Sync State ============

  /// Stores the current index.enc SHA for change detection.
  Future<void> setIndexSha(String sha) async {
    await _storage.write(key: SecureStorageKeys.indexSha, value: sha);
  }

  /// Retrieves the stored index SHA.
  Future<String?> getIndexSha() async {
    return _storage.read(key: SecureStorageKeys.indexSha);
  }

  /// Stores the config.yaml SHA.
  Future<void> setConfigSha(String sha) async {
    await _storage.write(key: SecureStorageKeys.configSha, value: sha);
  }

  /// Retrieves the stored config SHA.
  Future<String?> getConfigSha() async {
    return _storage.read(key: SecureStorageKeys.configSha);
  }

  /// Stores the last sync timestamp.
  Future<void> setLastSyncAt(DateTime time) async {
    await _storage.write(
      key: SecureStorageKeys.lastSyncAt,
      value: time.toIso8601String(),
    );
  }

  /// Retrieves the last sync timestamp.
  Future<DateTime?> getLastSyncAt() async {
    final value = await _storage.read(key: SecureStorageKeys.lastSyncAt);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  // ============ Vault Status ============

  /// Checks if the vault has been set up.
  Future<bool> isVaultConfigured() async {
    final salt = await getSalt();
    final pinHash = await getPinHash();
    final token = await getGitHubToken();
    return salt != null && pinHash != null && token != null;
  }

  /// Checks if the user is currently locked out.
  Future<bool> isLockedOut() async {
    final lockoutUntil = await getLockoutUntil();
    if (lockoutUntil == null) return false;
    return DateTime.now().isBefore(lockoutUntil);
  }

  /// Gets the remaining lockout duration.
  Future<Duration?> getRemainingLockout() async {
    final lockoutUntil = await getLockoutUntil();
    if (lockoutUntil == null) return null;
    final remaining = lockoutUntil.difference(DateTime.now());
    if (remaining.isNegative) return null;
    return remaining;
  }

  // ============ Cleanup ============

  /// Clears all stored data (for vault reset).
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Clears session data but keeps vault config.
  Future<void> clearSession() async {
    await clearMasterKey();
  }
}
