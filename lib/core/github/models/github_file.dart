import 'dart:convert';
import 'dart:typed_data';

/// Represents a file in a GitHub repository.
class GitHubFile {
  /// File name.
  final String name;

  /// Full path within the repository.
  final String path;

  /// SHA hash of the file content.
  final String sha;

  /// File size in bytes.
  final int size;

  /// Type: 'file', 'dir', or 'symlink'.
  final String type;

  /// Base64-encoded content (only present for file reads).
  final String? content;

  /// Download URL for raw file content.
  final String? downloadUrl;

  GitHubFile({
    required this.name,
    required this.path,
    required this.sha,
    required this.size,
    required this.type,
    this.content,
    this.downloadUrl,
  });

  /// Creates a GitHubFile from API JSON response.
  factory GitHubFile.fromJson(Map<String, dynamic> json) {
    return GitHubFile(
      name: json['name'] as String,
      path: json['path'] as String,
      sha: json['sha'] as String,
      size: json['size'] as int,
      type: json['type'] as String,
      content: json['content'] as String?,
      downloadUrl: json['download_url'] as String?,
    );
  }

  /// Decodes the base64 content to bytes.
  ///
  /// Returns null if content is not available.
  Uint8List? get decodedContent {
    if (content == null) return null;
    // GitHub adds newlines to base64 content
    final cleaned = content!.replaceAll('\n', '');
    return base64.decode(cleaned);
  }

  /// Returns true if this is a file (not directory or symlink).
  bool get isFile => type == 'file';

  /// Returns true if this is a directory.
  bool get isDirectory => type == 'dir';

  @override
  String toString() => 'GitHubFile($path, sha: ${sha.substring(0, 7)})';
}

/// Represents a commit in a GitHub repository.
class CommitInfo {
  /// Commit SHA.
  final String sha;

  /// Commit message.
  final String message;

  /// Author name.
  final String authorName;

  /// Author email.
  final String authorEmail;

  /// Commit timestamp.
  final DateTime date;

  CommitInfo({
    required this.sha,
    required this.message,
    required this.authorName,
    required this.authorEmail,
    required this.date,
  });

  /// Creates a CommitInfo from API JSON response.
  factory CommitInfo.fromJson(Map<String, dynamic> json) {
    final commit = json['commit'] as Map<String, dynamic>;
    final author = commit['author'] as Map<String, dynamic>;

    return CommitInfo(
      sha: json['sha'] as String,
      message: commit['message'] as String,
      authorName: author['name'] as String,
      authorEmail: author['email'] as String,
      date: DateTime.parse(author['date'] as String),
    );
  }

  @override
  String toString() => 'CommitInfo(${sha.substring(0, 7)}: $message)';
}
