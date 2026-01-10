import 'dart:convert';
import 'dart:typed_data';

import '../config/vault_config.dart';
import '../utils/result.dart';
import 'github_auth.dart';
import 'github_client.dart';
import 'github_errors.dart';
import 'rate_limit_tracker.dart';
import 'models/github_file.dart';

/// Repository for managing encrypted vault files on GitHub.
///
/// The vault structure:
/// ```
/// .aowl/
///   config.yaml      - KDF parameters, encryption settings
///   index.enc        - Encrypted index of all entries
///   data/
///     {uuid}.enc     - Encrypted entry files
/// ```
class VaultRepository {
  static const String vaultDir = '.aowl';
  static const String configFile = '$vaultDir/config.json';
  static const String indexFile = '$vaultDir/index.enc';
  static const String dataDir = '$vaultDir/data';

  final GitHubClient _client;
  final GitHubAuth _auth;

  VaultRepository({
    required GitHubAuth auth,
    GitHubClient? client,
  })  : _auth = auth,
        _client = client ?? GitHubClient(auth: auth);

  /// Verifies repository access and checks if vault exists.
  ///
  /// Returns:
  /// - Success(true) if vault exists and is accessible
  /// - Success(false) if repo exists but vault is not initialized
  /// - Failure with error if repo is not accessible
  Future<Result<bool, GitHubError>> verifyAccess() async {
    try {
      // Check repo access first
      final repoResponse = await _client.get(_auth.repoPath);
      if (repoResponse.statusCode != 200) {
        return Failure(_mapStatusToError(
          repoResponse.statusCode!,
          _auth.repoPath,
        ));
      }

      // Check if vault exists
      final configResponse = await _client.get(
        _auth.contentsPath(configFile),
      );

      return Success(configResponse.statusCode == 200);
    } on GitHubError catch (e) {
      return Failure(e);
    }
  }

  /// Downloads a file from the vault.
  Future<Result<Uint8List, GitHubError>> downloadFile(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        _auth.contentsPath(path),
      );

      if (response.statusCode == 404) {
        return Failure(NotFound(path));
      }

      if (response.statusCode != 200) {
        return Failure(_mapStatusToError(response.statusCode!, path));
      }

      final file = GitHubFile.fromJson(response.data!);
      final content = file.decodedContent;

      if (content == null) {
        return const Failure(UnknownGitHubError('File has no content'));
      }

      return Success(content);
    } on GitHubError catch (e) {
      return Failure(e);
    }
  }

  /// Downloads the encrypted index file.
  Future<Result<Uint8List, GitHubError>> downloadIndex() async {
    return downloadFile(indexFile);
  }

  /// Downloads the vault config (contains salt for key derivation).
  Future<Result<VaultConfig, GitHubError>> downloadVaultConfig() async {
    final result = await downloadFile(configFile);
    return result.map((bytes) => VaultConfig.fromJsonString(utf8.decode(bytes)));
  }

  /// Gets the current SHA of the config file.
  Future<Result<String?, GitHubError>> getConfigSha() async {
    final result = await getFileInfo(configFile);
    return switch (result) {
      Success(:final value) => Success(value.sha),
      Failure(error: NotFound _) => const Success(null),
      Failure(:final error) => Failure(error),
    };
  }

  /// Downloads an encrypted entry file.
  Future<Result<Uint8List, GitHubError>> downloadEntry(String entryId) async {
    return downloadFile('$dataDir/$entryId.enc');
  }

  /// Uploads a file to the vault.
  ///
  /// If [sha] is provided, updates existing file. Otherwise creates new.
  Future<Result<GitHubFile, GitHubError>> uploadFile({
    required String path,
    required Uint8List content,
    required String message,
    String? sha,
  }) async {
    try {
      final encodedContent = base64.encode(content);

      final data = <String, dynamic>{
        'message': message,
        'content': encodedContent,
      };

      if (sha != null) {
        data['sha'] = sha;
      }

      final response = await _client.put<Map<String, dynamic>>(
        _auth.contentsPath(path),
        data: data,
      );

      if (response.statusCode == 409) {
        return Failure(ConflictError(path, sha));
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        return Failure(_mapStatusToError(response.statusCode!, path));
      }

      final fileData = response.data!['content'] as Map<String, dynamic>;
      return Success(GitHubFile.fromJson(fileData));
    } on GitHubError catch (e) {
      return Failure(e);
    }
  }

  /// Uploads the vault config (contains salt for key derivation).
  Future<Result<GitHubFile, GitHubError>> uploadVaultConfig({
    required VaultConfig config,
    String? sha,
  }) async {
    return uploadFile(
      path: configFile,
      content: Uint8List.fromList(utf8.encode(config.toJsonString())),
      message: sha == null ? 'Initialize AOwl vault' : 'Update config',
      sha: sha,
    );
  }

  /// Uploads the encrypted index.
  Future<Result<GitHubFile, GitHubError>> uploadIndex({
    required Uint8List content,
    String? sha,
  }) async {
    return uploadFile(
      path: indexFile,
      content: content,
      message: sha == null ? 'Initialize vault index' : 'Update vault index',
      sha: sha,
    );
  }

  /// Uploads an encrypted entry.
  Future<Result<GitHubFile, GitHubError>> uploadEntry({
    required String entryId,
    required Uint8List content,
    String? sha,
  }) async {
    return uploadFile(
      path: '$dataDir/$entryId.enc',
      content: content,
      message: sha == null ? 'Add entry $entryId' : 'Update entry $entryId',
      sha: sha,
    );
  }

  /// Deletes a file from the vault.
  Future<Result<void, GitHubError>> deleteFile({
    required String path,
    required String sha,
    required String message,
  }) async {
    try {
      final response = await _client.delete(
        _auth.contentsPath(path),
        data: {
          'message': message,
          'sha': sha,
        },
      );

      if (response.statusCode != 200) {
        return Failure(_mapStatusToError(response.statusCode!, path));
      }

      return const Success(null);
    } on GitHubError catch (e) {
      return Failure(e);
    }
  }

  /// Deletes an encrypted entry.
  Future<Result<void, GitHubError>> deleteEntry({
    required String entryId,
    required String sha,
  }) async {
    return deleteFile(
      path: '$dataDir/$entryId.enc',
      sha: sha,
      message: 'Delete entry $entryId',
    );
  }

  /// Lists all files in a directory.
  Future<Result<List<GitHubFile>, GitHubError>> listDirectory(
    String path,
  ) async {
    try {
      final response = await _client.get<List<dynamic>>(
        _auth.contentsPath(path),
      );

      if (response.statusCode == 404) {
        return const Success([]); // Empty directory
      }

      if (response.statusCode != 200) {
        return Failure(_mapStatusToError(response.statusCode!, path));
      }

      final files = response.data!
          .map((json) => GitHubFile.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(files);
    } on GitHubError catch (e) {
      return Failure(e);
    }
  }

  /// Lists all entry files in the data directory.
  Future<Result<List<GitHubFile>, GitHubError>> listEntries() async {
    return listDirectory(dataDir);
  }

  /// Gets file metadata without downloading content.
  Future<Result<GitHubFile, GitHubError>> getFileInfo(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        _auth.contentsPath(path),
      );

      if (response.statusCode == 404) {
        return Failure(NotFound(path));
      }

      if (response.statusCode != 200) {
        return Failure(_mapStatusToError(response.statusCode!, path));
      }

      return Success(GitHubFile.fromJson(response.data!));
    } on GitHubError catch (e) {
      return Failure(e);
    }
  }

  /// Gets the current SHA of the index file.
  Future<Result<String?, GitHubError>> getIndexSha() async {
    final result = await getFileInfo(indexFile);
    return switch (result) {
      Success(:final value) => Success(value.sha),
      Failure(error: NotFound _) => const Success(null),
      Failure(:final error) => Failure(error),
    };
  }

  /// Returns the rate limit tracker for monitoring API usage.
  RateLimitTracker get rateLimits => _client.rateLimits;

  GitHubError _mapStatusToError(int statusCode, String path) {
    return switch (statusCode) {
      401 => const AuthenticationFailed(),
      403 => const AccessForbidden(),
      404 => NotFound(path),
      409 => ConflictError(path),
      429 => RateLimitExceeded(
          resetAt: rateLimits.resetAt,
          remaining: rateLimits.remaining,
        ),
      >= 500 => ServerError(statusCode),
      _ => UnknownGitHubError('HTTP $statusCode', statusCode),
    };
  }

  /// Closes the repository and releases resources.
  void close() {
    _client.close();
  }
}
